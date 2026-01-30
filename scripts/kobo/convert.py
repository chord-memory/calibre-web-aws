"""
The purpose of this script is to trick the Kobo into believing
sideloaded books on a Kobo have been CWA-loaded so that the Kobo
begins syncing reading progress %, annotations, etc with CWA, &
preventing CWA from duplicating sideloaded books during sync if
the sideloaded book also appears in CWA library.

NOTE: See KoboNotes.md explaining why this doesn't really work.
"""

import sys
import sqlite3
import argparse
import boto3
import botocore.exceptions
import json
from contextlib import contextmanager

ssm = boto3.client("ssm")

# Paths to CWA sqlite3 DBs on EC2
METADATA_DB_PATH = "/srv/library/metadata.db"
APP_DB_PATH = "/srv/config/app.db"


@contextmanager
def transaction(conn, dry_run):
    if dry_run:
        yield
    else:
        conn.execute("BEGIN IMMEDIATE;")
        try:
            yield
            conn.execute("COMMIT;")
        except Exception:
            conn.execute("ROLLBACK;")
            raise


def ssm_execute_command(instance_id, command):
    response = ssm.send_command(
        InstanceIds=[instance_id],
        DocumentName="AWS-RunShellScript",
        Parameters={
            "commands": [command]
        },
    )

    command_id = response["Command"]["CommandId"]

    failed = False
    try:
        ssm.get_waiter('command_executed').wait(
            CommandId=command_id,
            InstanceId=instance_id,
            WaiterConfig={
                'Delay': 2,
                'MaxAttempts': 10
            }
        )
    except botocore.exceptions.WaiterError:
        failed = True

    result = ssm.get_command_invocation(
        CommandId=command_id,
        InstanceId=instance_id,
    )

    if failed:
        raise RuntimeError(
            f"SSM command failed\n"
            f"Command: {command}\n"
            f"Status: {result['Status']}\n"
            f"ResponseCode: {result.get('ResponseCode')}\n"
            f"Stdout:\n{result.get('StandardOutputContent')}\n"
            f"Stderr:\n{result.get('StandardErrorContent')}\n"
        )

    return result["StandardOutputContent"].strip()
    

def fetch_cwa_books_via_ssm(instance_id):
    command = f'sqlite3 "{METADATA_DB_PATH}" -json "SELECT title, uuid FROM books;"'
    stdout = ssm_execute_command(instance_id, command)
    rows = json.loads(stdout)
    return {row["title"]: row["uuid"] for row in rows}


def fetch_cwa_shelf_via_ssm(instance_id, shelf):
    command = f'sqlite3 "{APP_DB_PATH}" -json "SELECT uuid FROM shelf WHERE name=\'{shelf}\';"'
    stdout = ssm_execute_command(instance_id, command)
    if not stdout:
        raise Exception(f"The shelf '{shelf}' should already exist in CWA")
    rows = json.loads(stdout)
    if len(rows) != 1:
        raise Exception(f"Exactly one shelf '{shelf}' should already exist in CWA")
    return rows[0]["uuid"]


def confirm(dry_run):
    msg = "\nProceed with dry-run? [y/N] " if dry_run else "\nProceed with db changes? [y/N] "
    resp = input(msg).strip().lower()
    if resp != "y":
        print("\nAborted by user")
        sys.exit(0)


def main(kobo_db, instance_id, title, shelf, assume_yes, dry_run):
    # Build title → CWA UUID map
    cwa_books = fetch_cwa_books_via_ssm(instance_id)

    # Get shelf UUID from CWA
    shelf_uuid = fetch_cwa_shelf_via_ssm(instance_id, shelf)

    kobo = sqlite3.connect(kobo_db)
    kobo.row_factory = sqlite3.Row

    # Get Kobo user UUID
    user_id = kobo.execute(
        "SELECT UserID FROM user LIMIT 1"
    ).fetchone()["UserID"]

    # Select sideloaded books from Kobo
    if title == 'all':
        sideloaded = kobo.execute("""
            SELECT ContentID, Title
            FROM content
            WHERE ___UserID = 'kepub_user'
            AND BookID IS NULL
            AND Title IS NOT NULL
        """).fetchall()
    else:
        sideloaded = kobo.execute("""
            SELECT ContentID, Title
            FROM content
            WHERE ___UserID = 'kepub_user'
            AND BookID IS NULL
            AND Title=?
        """, (title,)).fetchall()

        if len(sideloaded) > 1:
            print(f"ABORT: Multiple books with title '{title}' sideloaded on Kobo")
            return
        if len(sideloaded) == 0:
            print(f"ABORT: No books with title '{title}' sideloaded on Kobo")
            return

    print(f"Found {len(sideloaded)} sideloaded candidates")

    for row in sideloaded:
        title = row["Title"]
        old_id = row["ContentID"]

        if title not in cwa_books:
            print(f"SKIP: '{title}' not found in CWA")
            continue

        # New ContentID for main book entry on Kobo will be CWA UUID
        new_id = cwa_books[title]

        # Conflict check
        exists = kobo.execute(
            "SELECT 1 FROM content WHERE ContentID = ?",
            (new_id,)
        ).fetchone()

        if exists:
            print(f"SKIP: '{title}' UUID already exists on Kobo")
            continue

        print(f"CONVERT: {title}")
        print(f"  {old_id} → {new_id}")

    db_shelf = kobo.execute("""
        SELECT Id FROM Shelf WHERE Name=?
    """, (shelf,)).fetchall()

    if len(db_shelf) > 1:
        print(f"ABORT: Multiple shelfs with name '{shelf}' already on Kobo")
        return
    elif len(db_shelf) == 1:
        if shelf_uuid != db_shelf[0]['Id']:
            print(f"ABORT: Shelf with name '{shelf}' already on Kobo under unknown UUID")
            return
        print(f"NOTE: Will add books to existing shelf '{shelf}'")
        new_shelf = False
    else:
        print(f"NOTE: Will add books to new shelf '{shelf}'")
        new_shelf = True

    if not assume_yes:
        confirm(dry_run)

    with transaction(kobo, dry_run):
        if new_shelf:
            kobo.execute("""
                INSERT INTO Shelf
                (Id, InternalName, Name, _IsDeleted, _IsVisible, _IsSynced, Type)
                VALUES (?, ?, ?, false, true, true, 'UserTag');
            """, (shelf_uuid, shelf, shelf))

        for row in sideloaded:
            kobo.execute("""
                UPDATE content SET
                ContentID=?, WorkId=?, EntitlementId=?, CrossRevisionId=?,
                DownloadUrl=true, ___UserID=?, ReadStateSynced=true
                WHERE BookID IS NULL AND ContentID=?
            """, (new_id, new_id, new_id, new_id, user_id, old_id))

            kobo.execute(
                "UPDATE content SET BookID=? WHERE BookID=?",
                (new_id, old_id)
            )

            for table, col in [
                ("content_settings", "ContentID"),
                ("Bookmark", "VolumeID"),
                ("volume_shortcovers", "volumeId"),
                ("WordList", "VolumeId"),
                ("Event", "ContentID"),
                ("Activity", "Id"),
                ("ShelfContent", "ContentId")
            ]:
                kobo.execute(
                    f"UPDATE {table} SET {col}=? WHERE {col}=?",
                    (new_id, old_id)
                )

            kobo.execute("""
                INSERT OR IGNORE INTO ShelfContent
                (ShelfName, ContentId, _IsDeleted, _IsSynced)
                VALUES (?, ?, false, true);
            """, (shelf, new_id))

    kobo.close()

    if dry_run:
        print("\nDRY RUN COMPLETE — no changes written")
    else:
        print("\nDONE — eject Kobo safely")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--kobo-db", required=True, help="path to KoboReader.sqlite on Kobo")
    parser.add_argument("--instance", dest="instance_id", required=True, help="EC2 instance id where CWA is running")
    parser.add_argument("--title", required=True, help="title of book to convert or 'all'")
    parser.add_argument("--shelf", required=True, help="name of CWA shelf to sync to Kobo")
    parser.add_argument("--yes", dest="assume_yes", action="store_true", help="skip confirmation")
    parser.add_argument("--dry-run", action="store_true", help="echo results without committing to DB")
    args = parser.parse_args()

    main(args.kobo_db, args.instance_id, args.title, args.shelf, args.assume_yes, args.dry_run)
