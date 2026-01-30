"""
The purpose of this script is to transfer the state of 1 or more
sideloaded books on a Kobo to its CWA-loaded equivilent. This
includes annotations, reading progress, saved words, etc.
"""

import sys
import sqlite3
import argparse
import uuid
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import datetime, timezone


@dataclass
class TransferData:
    title: str
    cwa_id: str
    sideloaded_id: str


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


def confirm(dry_run):
    msg = "\nProceed with dry-run? [y/N] " if dry_run else "\nProceed with db changes? [y/N] "
    resp = input(msg).strip().lower()
    if resp != "y":
        print("\nAborted by user")
        sys.exit(0)

def text_factory(x):
    # If text values are stored in blob field
    # and sqlite3 module attempts to decode them
    # but fails, just leave as bytes
    # e.g. ExtraData field in Event table 
    try:
        return str(x, 'utf-8')
    except UnicodeDecodeError:
        return x

def main(kobo_db, title, assume_yes, dry_run):
    kobo = sqlite3.connect(kobo_db)
    kobo.row_factory = sqlite3.Row
    kobo.text_factory = text_factory

    # CWA books have Kobo user UUID
    user_id = kobo.execute(
        "SELECT UserID FROM user LIMIT 1"
    ).fetchone()["UserID"]

    # Select sideloaded books from Kobo
    if title == 'all':
        sideloaded_books = kobo.execute("""
            SELECT ContentID, Title
            FROM content
            WHERE ___UserID = 'kepub_user'
            AND BookID IS NULL
            AND Title IS NOT NULL
        """).fetchall()
    else:
        sideloaded_books = kobo.execute("""
            SELECT ContentID, Title
            FROM content
            WHERE ___UserID = 'kepub_user'
            AND BookID IS NULL
            AND Title=?
        """, (title,)).fetchall()
        
        if len(sideloaded_books) > 1:
            print(f"ABORT: Multiple books with title '{title}' sideloaded on Kobo")
            return
        if len(sideloaded_books) == 0:
            print(f"ABORT: No books with title '{title}' sideloaded on Kobo")
            return

    print(f"Found {len(sideloaded_books)} sideloaded candidates")

    transfer_data = []

    for book in sideloaded_books:
        title = book["Title"]
        sideloaded_id = book["ContentID"]

        cwa_book = kobo.execute("""
            SELECT ContentID, IsDownloaded, DateCreated FROM content
            WHERE ___UserID = ?
            AND BookID IS NULL AND Title = ?
        """, (user_id, title,)).fetchall()

        if len(cwa_book) > 1:
            print(f"SKIP: Multiple books with title '{title}' CWA-loaded on Kobo")
            continue
        if len(cwa_book) == 0:
            print(f"SKIP: No books with title '{title}' CWA-loaded on Kobo")
            continue
        
        cwa_id = cwa_book[0]['ContentID']
        downloaded = cwa_book[0]['IsDownloaded']

        # Transferred data will be erased when book is downloaded
        # so ensure download has already occurred
        if not downloaded:
            print(f"SKIP: CWA-loaded book '{title}' must be downloaded to continue")
            continue

        transfer_data.append(
            TransferData(
                title=title,
                cwa_id=cwa_id,
                sideloaded_id=sideloaded_id
            )
        )

        print(f"TRANSFER: {title}")
        print(f"  {sideloaded_id} → {cwa_id}")

    # Take note of CWA-loaded books without sideloaded equivalent
    if title == 'all':
        transfer_titles = set([
            data.title for data in transfer_data
        ])
        cwa_books = kobo.execute("""
            SELECT Title
            FROM content
            WHERE ___UserID = ?
            AND BookID IS NULL
            AND Title IS NOT NULL
        """, (user_id,)).fetchall()
        cwa_titles = set([
            book['Title'] for book in cwa_books
        ])
        excess_cwa = cwa_titles - transfer_titles
        for cwa_book in excess_cwa:
            print(f"WARNING: CWA-loaded book '{cwa_book}' has no sideloaded equivalent")

    if not assume_yes:
        confirm(dry_run)

    with transaction(kobo, dry_run):
        for data in transfer_data:
            title = data.title
            cwa_id = data.cwa_id
            sideloaded_id = data.sideloaded_id

            print(f"Transferring '{data.title}'")

            # Transfer notable fields from content between sideloaded
            # row and CWA-loaded row for main book entry only
            content = kobo.execute("""
                SELECT DateLastRead, ChapterIDBookmarked, ReadStatus, DateCreated,
                ___PercentRead, RestOfBookEstimate, CurrentChapterEstimate,
                CurrentChapterProgress, TimeSpentReading from content
                WHERE BookID IS NULL AND ContentID = ?
            """, (sideloaded_id,)).fetchone()

            print(f"    Transferring content fields")
            kobo.execute("""
                UPDATE content SET DateLastRead=?, FirstTimeReading=?,
                ChapterIDBookmarked=?, ReadStatus=?, ___PercentRead=?,
                RestOfBookEstimate=?, CurrentChapterEstimate=?, CurrentChapterProgress=?,
                TimesStartedReading=?, TimeSpentReading=?, LastTimeStartedReading=?
                WHERE BookID IS NULL AND ContentID=?
            """, (
                content['DateLastRead'],
                False, # Kobo should consider the book as having already been opened
                content['ChapterIDBookmarked'],
                content['ReadStatus'],
                content['___PercentRead'],
                content['RestOfBookEstimate'],
                content['CurrentChapterEstimate'],
                content['CurrentChapterProgress'],
                0 if content['___PercentRead'] == 0 else 1,
                content['TimeSpentReading'],
                content['DateCreated'], # LastTimeStartedReading not stored for sideloaded books
                cwa_id
            ))

            # Generate subentries map
            subentries = kobo.execute("""
                SELECT
                    a.ShortcoverId  AS cwa_subentry_id,
                    b.ShortcoverId  AS sideloaded_subentry_id
                FROM volume_shortcovers AS a
                JOIN volume_shortcovers AS b
                ON a.VolumeIndex = b.VolumeIndex
                WHERE a.VolumeId = ?
                AND b.VolumeId = ?
                ORDER BY a.VolumeIndex;
            """, (cwa_id, sideloaded_id)).fetchall()

            subentries_map = {
                subentry["sideloaded_subentry_id"]: subentry["cwa_subentry_id"]
                for subentry in subentries
            }

            # Duplicate rows of notable tables replacing sideloaded content ID
            # with CWA-loaded content ID
            for table, book_id_col in [
                ("Bookmark", "VolumeID"),
                ("content_settings", "ContentID"),
                ("Event", "ContentID"),
            ]:
                rows = kobo.execute(f"""
                    SELECT * FROM {table}
                    WHERE {book_id_col} = ?
                """, (sideloaded_id,)).fetchall()

                if not rows:
                    print(f"    No {table} entries to transfer")
                    continue
                
                cwa_rows = kobo.execute(f"""
                    SELECT * FROM {table}
                    WHERE {book_id_col} = ?
                """, (cwa_id,)).fetchall()

                if cwa_rows and not (
                    table == "Event"
                    and len(cwa_rows) == 1
                    and cwa_rows[0]['EventType'] == 4
                ):
                    # We do not want to transfer data that already exists for the CWA-loaded book
                    # by accident if the CWA-loaded book has already been opened.
                    # It is ok tho for just the Event table to already have 1 row where EventType == 4.
                    # I believe this is the download event. Only exists for CWA-loaded books
                    # so won't be duplicated during transfer from sideloaded book.
                    raise Exception(
                        f"CWA-loaded books should have no state, yet entries found in '{table}'\n"
                        f"  {title=}\n"
                        f"  {cwa_id=}\n"
                        f"  {sideloaded_id=}"
                    )

                print(f"    Transferring {len(rows)} {table} entries")
                columns = list(rows[0].keys())
                col_list = ', '.join(columns)
                placeholders = ", ".join("?" for _ in columns)

                insert_sql = f"""
                    INSERT INTO {table} ({col_list})
                    VALUES ({placeholders})
                """

                values_to_insert = []

                for row in rows:
                    values = []
                    # For each column, the value to insert is the original value
                    # unless the column is the content ID column in which case
                    # the CWA ID replaces the sideloaded ID
                    for col in columns:
                        # For the Bookmark table only, we also need to replace the subentry
                        # content ID field with the mapped subentry content ID for the CWA-loaded
                        # equivalent of the sideloaded book
                        if table == 'Bookmark':
                            if col == 'ContentID':
                                sideloaded_subentry_id = row[col]
                                cwa_subentry_id = subentries_map.get(sideloaded_subentry_id)
                                if cwa_subentry_id is None:
                                    raise Exception(
                                        f'Unknown CWA-loaded subentry ID for sideloaded subentry ID\n'
                                        f'  {sideloaded_subentry_id=}\n'
                                        f'  {title=}\n'
                                        f'  {cwa_id=}\n'
                                        f'  {sideloaded_id=}'
                                    )
                                values.append(cwa_subentry_id)
                                continue
                            # Generate a random UUID to be the BookmarkID instead of duplicating
                            # to avoid primary key unique constraint
                            if col == 'BookmarkID':
                                values.append(str(uuid.uuid4()))
                                continue
                        if col == book_id_col:
                            values.append(cwa_id)
                        else:
                            values.append(row[col])
                    values_to_insert.append(values)

                kobo.executemany(insert_sql, values_to_insert)

            # Edit the VolumeId in WordList entries from the sideloaded ID
            # to the CWA-loaded ID.
            # Cannot duplicate bc the word itself is the primary key
            word_count = kobo.execute(
                f"SELECT COUNT(*) AS word_count FROM WordList WHERE VolumeId = ?",
                (sideloaded_id,)
            ).fetchone()['word_count']
            print(f"    Transferring {word_count} WordList entries")
            kobo.execute(
                f"UPDATE WordList SET VolumeId=? WHERE VolumeId=?",
                (cwa_id, sideloaded_id)
            )

    kobo.close()

    if dry_run:
        print("\nDRY RUN COMPLETE — no changes written")
    else:
        print("\nDONE — eject Kobo safely")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--kobo-db", required=True, help="path to KoboReader.sqlite on Kobo")
    parser.add_argument("--title", required=True, help="title of book to transfer or 'all'")
    parser.add_argument("--yes", dest="assume_yes", action="store_true", help="skip confirmation")
    parser.add_argument("--dry-run", action="store_true", help="echo results without committing to DB")
    args = parser.parse_args()

    main(args.kobo_db, args.title, args.assume_yes, args.dry_run)


# Try opening the CWA-loaded book just to the cover page and then doing the transfer
# in case there is some caching of subfiles or something that is necessary
# See about this bookmark chatgpt mentions for current book placement
# for cwa loaded books although I don't see it in Bookmark table

# Ok figuring out how to transfer ChapterIDBookmarked for entries and subentries
# Try again with book not downloaded and also with it downloaded

# Consider populating LastTimeFinishedReading based on Event