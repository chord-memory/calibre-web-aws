# `KoboReader.sqlite` Explained

Connect to `KoboReader.sqlite` by plugging the Kobo into your Mac and opening the `KoboReader.sqlite` from the Kobo Volume with `sqlite3`:
```
jordan@Jordans-MBP ~ % sqlite3 /Volumes/KOBOeReader/.kobo/KoboReader.sqlite
SQLite version 3.43.2 2023-10-10 13:08:14
Enter ".help" for usage hints.
sqlite> .tables
AbTest                 KoboPlusAssetGroup     Wishlist             
Achievement            KoboPlusAssets         WordList             
Activity               OverDriveCards         content              
AnalyticsEvents        OverDriveCheckoutBook  content_keys         
Authors                OverDriveLibrary       content_settings     
BookAuthors            Reviews                ratings              
Bookmark               Rules                  shortcover_page      
DbVersion              Shelf                  user                 
DropboxItem            ShelfContent           volume_shortcovers   
Event                  SubscriptionProducts   volume_tabs          
GDriveItem             SyncQueue            
KoblimeSync            Tab                  
sqlite>
```

## `content` Overview

The `content` table is the most important table in the Kobo database. There are 2 different types of entries in the `content` table: 1 main entry per book and multiple sub-entries per book. When there is no `BookID` for an entry, the entry is the main book entry, and the `ContentID` is the primary ID for the book. For the remaining sub-entries, the `BookID` will be the `ContentID` from the main book entry, and the `ContendID` represents subfiles of the main ePub file.

If the book was sideloaded, the format of the `ContentID` is file-system-based: `file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub`. If the book was loaded via Calibre-Web, the format of the `ContentID` is a UUID like `6f03d308-6370-4dc6-935b-2aede5cc81c3`, and matches the `uuid` in the `books` table in `metadata.db` in the ~/calibre-library directory of your Calibre-Web/CWA server.

Below I show some query results from the database on my Kobo where I have both sideloaded and Calibre-Web/CWA-loaded books. For the `content` table, I only select fields that may differ between sideloaded and Calibre-Web/CWA-loaded books, and fields that have a relationship with other tables. The other tables I outline are only those which relate to the `content` table. There are additional tables relating to `content` which I do not outline e.g. `Reviews` and `ratings` bc I do not use these features.

## Main Book Entries in `content`

See examples below for both sideloaded and Calibre-Web/CWA loaded books:
```
sqlite> select ContentID, BookID, Title, BookTitle, VolumeIndex, NumShortcovers, ___UserID, isEncrypted, isDownloaded, DownloadUrl, ReadStateSynced from content where Title = "How Linux Works";
ContentID                                                     BookID  Title            BookTitle  VolumeIndex  NumShortcovers  ___UserID                             IsEncrypted  IsDownloaded  DownloadUrl  ReadStateSynced
------------------------------------------------------------  ------  ---------------  ---------  -----------  --------------  ------------------------------------  -----------  ------------  -----------  ---------------
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward          How Linux Works             -1           27              kepub_user                            true         true          false        false          
.kepub.epub                                                                                                                                                                                                                 

6f03d308-6370-4dc6-935b-2aede5cc81c3                                  How Linux Works             -1           27              d5e94a94-bc32-4b48-b229-6de0c8e31665  true         true          true         true           
```

| Field             | Description                                                                                                                   |
| ----------------- | ------------------------------------------------------------------------------------------------------------------------------|
| `ContentID`       | The primary ID for the EPUB (UUID for Calibre-Web/CWA books; file-based ID for sideloaded books)                              |
| `BookID`          | Empty (not used for main book entries)                                                                                        |
| `Title`           | The book title                                                                                                                |
| `BookTitle`       | Empty (title is stored in `Title` instead)                                                                                    |
| `VolumeIndex`     | `-1` indicating a standalone book (not part of a volume set)                                                                  |
| `NumShortcovers`  | Number of `volume_shortcovers` entries generated for the EPUB (`0` if book is synced but not downloaded from Calibre-Web/CWA) |
| `___UserID`       | `"kepub_user"` for sideloaded books; the user UUID from the `users` table for Calibre-Web–loaded books                        |
| `IsEncrypted`     | `true`; indicates Kobo DRM/container handling (even for non-DRM kepubs)                                                       |
| `IsDownloaded`    | `true` if the book file exists on the device; `false` if synced but not downloaded from Calibre-Web                           |
| `DownloadUrl`     | `true` for Calibre-Web books; `false` for sideloaded books                                                                    |
| `ReadStateSynced` | `true` for Calibre-Web books (reading state synced); `false` for sideloaded books                                             |


See my `user` entry here. A Kobo could have multiple `user` entries but this is more complex so I will assume 1 `user` entry.
```
sqlite> select UserID, UserDisplayName, UserEmail from user;
UserID                                UserDisplayName           UserEmail               
------------------------------------  ------------------------  ------------------------
d5e94a94-bc32-4b48-b229-6de0c8e31665  jordancahill88@gmail.com  jordancahill88@gmail.com
```

Note that for Calibre-Web/CWA-loaded books, the `ContentID` UUID for the main book entry appears also in the `ImageId`, `WorkId`, `EntitlementId`, and `CrossRevisionId` fields. For sideloaded books, the `ImageId` is equivilant to the `ContentID` if all special characters besides the command and dash are replaced with underscores. `WorkId`, `EntitlementId`, and `CrossRevisionId` are null for sideloaded books.
```
sqlite> select ContentID, BookID, Title, BookTitle, ImageId, WorkId, EntitlementId, CrossRevisionId from content where Title = "How Linux Works";
ContentID                                                     BookID  Title            BookTitle  ImageId                                                       WorkId                                EntitlementId                         CrossRevisionId                     
------------------------------------------------------------  ------  ---------------  ---------  ------------------------------------------------------------  ------------------------------------  ------------------------------------  ------------------------------------
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward          How Linux Works             file____mnt_onboard_Ward,_Brian_How_Linux_Works_-_Brian_Ward                                                                                                                  
.kepub.epub                                                                                       _kepub_epub                                                                                                                                                                   

6f03d308-6370-4dc6-935b-2aede5cc81c3                                  How Linux Works             6f03d308-6370-4dc6-935b-2aede5cc81c3                          6f03d308-6370-4dc6-935b-2aede5cc81c3  6f03d308-6370-4dc6-935b-2aede5cc81c3  6f03d308-6370-4dc6-935b-2aede5cc81c3

```
I suspect that the `ImageId` may allow the Kobo to find the local ePub files somehow but I am not sure. I don't know the purpose of the `WorkId`, `EntitlementId`, and `CrossRevisionId` fields but want to note these fields' relevance to the `ContentID` for the main book entry.

## Sub-Entries in `content`

See examples below for both sideloaded and Calibre-Web loaded books:
```
sqlite> select ContentID, BookID, Title, BookTitle, VolumeIndex, NumShortcovers, ___UserID, isEncrypted, isDownloaded, DownloadUrl, ReadStateSynced from content where BookID = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" order by VolumeIndex limit 3;
ContentID                                                     BookID                                                        Title                        BookTitle        VolumeIndex  NumShortcovers  ___UserID  IsEncrypted  IsDownloaded  DownloadUrl  ReadStateSynced
------------------------------------------------------------  ------------------------------------------------------------  ---------------------------  ---------------  -----------  --------------  ---------  -----------  ------------  -----------  ---------------
/mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  cover.xhtml                  How Linux Works  0                                       false        1                          false          
epub!OPS!cover.xhtml                                          .kepub.epub                                                                                                                                                                                                

/mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  Reviews for How Linux Works  How Linux Works  0                                       false        1                          false          
epub!OPS!f01.xhtml-1                                          .kepub.epub                                                                                                                                                                                                

/mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  toc.xhtml                    How Linux Works  1                                       false        1                          false          
epub!OPS!toc.xhtml                                            .kepub.epub                                                                                                                                                                                                
```
```
sqlite> select ContentID, BookID, Title, BookTitle, VolumeIndex, NumShortcovers, ___UserID, isEncrypted, isDownloaded, DownloadUrl, ReadStateSynced from content where BookID = "6f03d308-6370-4dc6-935b-2aede5cc81c3" order by VolumeIndex limit 3; 
ContentID                                             BookID                                Title                        BookTitle        VolumeIndex  NumShortcovers  ___UserID                             IsEncrypted  IsDownloaded  DownloadUrl  ReadStateSynced
----------------------------------------------------  ------------------------------------  ---------------------------  ---------------  -----------  --------------  ------------------------------------  -----------  ------------  -----------  ---------------
6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!cover.xhtml  6f03d308-6370-4dc6-935b-2aede5cc81c3  cover.xhtml                  How Linux Works  0                            d5e94a94-bc32-4b48-b229-6de0c8e31665  false        1                          false          
6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!f01.xhtml-1  6f03d308-6370-4dc6-935b-2aede5cc81c3  Reviews for How Linux Works  How Linux Works  0                            d5e94a94-bc32-4b48-b229-6de0c8e31665  false        1                          false          
6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!toc.xhtml    6f03d308-6370-4dc6-935b-2aede5cc81c3  toc.xhtml                    How Linux Works  1                            d5e94a94-bc32-4b48-b229-6de0c8e31665  false        1                          false          
```

| Field             | Description                                                                                               |
| ----------------- | ----------------------------------------------------------------------------------------------------------|
| `ContentID`       | The primary ID for the EPUB followed by OPS data for EPUB sub-files (each entry represents EPUB sub-file  |
| `BookID`          | The primary ID for the EPUB (UUID for Calibre-Web/CWA books; file-based ID for sideloaded books)          |
| `Title`           | The EPUB sub-file name(e.g., cover.xhtml, toc.xhtml, chapter titles)                                      |
| `BookTitle`       | The book title (duplicated from the parent book row)                                                      |
| `VolumeIndex`     | The order of the EPUB sub-file within the spine (may repeat for auxiliary files e.g. reviews, cover, nav) |
| `NumShortcovers`  | `null` (only populated on the main book row)                                                              |
| `___UserID`       | `null` for sideloaded books; the user UUID from the `users` table for Calibre-Web/CWA–loaded books        |
| `IsEncrypted`     | `false` (sub-files themselves are not encrypted)                                                          |
| `IsDownloaded`    | `1` (sub-files always exist if the parent EPUB is present)                                                |
| `DownloadUrl`     | `null` (only meaningful for the main book entry)                                                          |
| `ReadStateSynced` | `false` (reading state is tracked only on the main book row)                                              |

Just to note, the `ImageId`, `WorkId`, `EntitlementId`, and `CrossRevisionId` fields are null for `content` sub-entries.
```
sqlite> select ContentID, BookID, Title, BookTitle, ImageId, WorkId, EntitlementId, CrossRevisionId from content where BookID = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" order by VolumeIndex limit 3;
ContentID                                                     BookID                                                        Title                        BookTitle        ImageId  WorkId  EntitlementId  CrossRevisionId
------------------------------------------------------------  ------------------------------------------------------------  ---------------------------  ---------------  -------  ------  -------------  ---------------
/mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  cover.xhtml                  How Linux Works                                                 
epub!OPS!cover.xhtml                                          .kepub.epub                                                                                                                                                

/mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  Reviews for How Linux Works  How Linux Works                                                 
epub!OPS!f01.xhtml-1                                          .kepub.epub                                                                                                                                                

/mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  toc.xhtml                    How Linux Works                                                 
epub!OPS!toc.xhtml                                            .kepub.epub                                                                                                                                                
sqlite> select ContentID, BookID, Title, BookTitle, ImageId, WorkId, EntitlementId, CrossRevisionId from content where BookID = "6f03d308-6370-4dc6-935b-2aede5cc81c3" order by VolumeIndex limit 3;
ContentID                                             BookID                                Title                        BookTitle        ImageId  WorkId  EntitlementId  CrossRevisionId
----------------------------------------------------  ------------------------------------  ---------------------------  ---------------  -------  ------  -------------  ---------------
6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!cover.xhtml  6f03d308-6370-4dc6-935b-2aede5cc81c3  cover.xhtml                  How Linux Works                                                 
6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!f01.xhtml-1  6f03d308-6370-4dc6-935b-2aede5cc81c3  Reviews for How Linux Works  How Linux Works                                                 
6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!toc.xhtml    6f03d308-6370-4dc6-935b-2aede5cc81c3  toc.xhtml                    How Linux Works                                                 
```

## Removed Books in `content`

Be aware that when sideloaded books are removed in the Kobo, so is their data from the `content` table. However, when Calibre-Web/CWA-loaded books are removed, the main book entry remains in `content`, with `isDownloaded` changed to `false` and `___UserID` changed to `removed`. The sub-entries for the Calibre-Web/CWA-loaded book are deleted.
```
sqlite> select ContentID, BookID, Title, BookTitle, VolumeIndex, NumShortcovers, ___UserID, isEncrypted, isDownloaded, DownloadUrl, ReadStateSynced from content where Title = "Flash Boys: A Wall Street Revolt";
ContentID                             BookID  Title                             BookTitle  VolumeIndex  NumShortcovers  ___UserID  IsEncrypted  IsDownloaded  DownloadUrl  ReadStateSynced
------------------------------------  ------  --------------------------------  ---------  -----------  --------------  ---------  -----------  ------------  -----------  ---------------
4b02b689-718d-4f2b-bdc7-29010b8b9aa4          Flash Boys: A Wall Street Revolt             -1           19              removed    true         false         true         true           
sqlite> select count(*) from content where BookID = "4b02b689-718d-4f2b-bdc7-29010b8b9aa4";
count(*)
--------
0  
```
The entries for the removed book in the other related tables may be deleted as well or may not. For both sideloaded or Calibre-Web/CWA-loaded books. Just wanted to document this.
```
sqlite> select count(*) from volume_shortcovers where volumeId = "4b02b689-718d-4f2b-bdc7-29010b8b9aa4";
count(*)
--------
0      
sqlite> select count(*) from Event where ContentID = "4b02b689-718d-4f2b-bdc7-29010b8b9aa4";
count(*)
--------
1       
sqlite> select count(*) from content where ContentID = "file:///mnt/onboard/Hane, Mikiso/Premodern Japan_ A Historical Survey - Mikiso Hane & Louis G. Perez.kepub.epub";
count(*)
--------
0       
sqlite> select count(*) from volume_shortcovers where volumeId = "file:///mnt/onboard/Hane, Mikiso/Premodern Japan_ A Historical Survey - Mikiso Hane & Louis G. Perez.kepub.epub";
count(*)
--------
0       
sqlite>
sqlite> select count(*) from Event where ContentID = "file:///mnt/onboard/Hane, Mikiso/Premodern Japan_ A Historical Survey - Mikiso Hane & Louis G. Perez.kepub.epub";
count(*)
--------
1       
```

## Other Related Tables

For `volume_shortcovers`, the `volumeId` field is the `ContentID` for the main book entry in the `content` table. The `shortcoverId` & `VolumeIndex` match the `ContentID` & `VolumeIndex` from the `content` sub-entries.
```
sqlite> select * from volume_shortcovers where volumeId = "6f03d308-6370-4dc6-935b-2aede5cc81c3" order by VolumeIndex limit 3;
volumeId                              shortcoverId                                          VolumeIndex
------------------------------------  ----------------------------------------------------  -----------
6f03d308-6370-4dc6-935b-2aede5cc81c3  6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!cover.xhtml  0          
6f03d308-6370-4dc6-935b-2aede5cc81c3  6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!toc.xhtml    1          
6f03d308-6370-4dc6-935b-2aede5cc81c3  6f03d308-6370-4dc6-935b-2aede5cc81c3!OPS!f01.xhtml    2       
```
```
sqlite> select * from volume_shortcovers where volumeId = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" order by VolumeIndex limit 4;
volumeId                                                      shortcoverId                                                  VolumeIndex
------------------------------------------------------------  ------------------------------------------------------------  -----------
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  0          
.kepub.epub                                                   epub!OPS!cover.xhtml                                                     

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  1          
.kepub.epub                                                   epub!OPS!toc.xhtml                                                       

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  2          
.kepub.epub                                                   epub!OPS!f01.xhtml                                                       

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  3          
.kepub.epub                                                   epub!OPS!f02.xhtml                                                       
```

Below are several other tables which relate to `content` via the `ContentID` for the main book entry. There are additional tables relating to `content` which I do not list below e.g. `Reviews` and `ratings` bc I do not use these features and the tables are empty.
| Table Name         | Field Name containing `ContentID` for main book entry from `content` |
| -------------------| ---------------------------------------------------------------------|
| `content_settings` | `ContentID`  |
| `WordList`         | `VolumeId`   |
| `Event`            | `ContentID`  |
| `Activity`         | `Id`         |

The table details are shows below for these:
```
sqlite> pragma table_info(content_settings);
cid  name                     type     notnull  dflt_value  pk
---  -----------------------  -------  -------  ----------  --
0    ContentID                TEXT     1                    1 
1    ContentType              INTEGER  1                    2 
2    DateModified             TEXT     1                    0 
3    ReadingFontFamily        TEXT     0                    0 
4    ReadingFontSize          INTEGER  0                    0 
5    ReadingAlignment         TEXT     0                    0 
6    ReadingLineHeight        REAL     0                    0 
7    ReadingLeftMargin        INTEGER  0                    0 
8    ReadingRightMargin       INTEGER  0                    0 
9    ReadingPublisherMode     INTEGER  0                    0 
10   ActivityFacebookShare    BIT      0        TRUE        0 
11   RecentBookSearches       TEXT     0                    0 
12   AuthorNotesShown         BIT      0        false       0 
13   LastAuthorNotesSyncTime  TEXT     0                    0 
14   ZoomFactor               INTEGER  0        1           0 
15   BTBFooterSection         TEXT     0                    0 
16   SelectedDictionary       TEXT     0                    0 
17   StillReading             BIT      0        FALSE       0 
18   SeriesShown              BIT      0        FALSE       0 
sqlite> pragma table_info(WordList);
cid  name         type  notnull  dflt_value  pk
---  -----------  ----  -------  ----------  --
0    Text         TEXT  0                    1 
1    VolumeId     TEXT  0                    0 
2    DictSuffix   TEXT  0                    0 
3    DateCreated  TEXT  0                    0 
sqlite> pragma table_info(Event);
cid  name             type     notnull  dflt_value  pk
---  ---------------  -------  -------  ----------  --
0    EventType        INTEGER  1                    1 
1    FirstOccurrence  TEXT     0                    0 
2    LastOccurrence   TEXT     0                    0 
3    EventCount       INTEGER  0        0           0 
4    ContentID        TEXT     0                    2 
5    ExtraData        BLOB     0                    0 
6    Checksum         TEXT     0                    0 
sqlite> pragma table_info(Activity);
cid  name     type     notnull  dflt_value  pk
---  -------  -------  -------  ----------  --
0    Id       TEXT     0                    1 
1    Enabled  BIT      0        TRUE        0 
2    Type     TEXT     0                    2 
3    Action   INTEGER  0                    0 
4    Date     TEXT     0                    0 
5    Data     BLOB     0                    0
```


## `Bookmark` Table

The `Bookmark` table also relates to `content` via the `ContentID` for the main book entry in `content` but I will outline it separately due to its importance and complexity.
```
sqlite> pragma table_info(Bookmark);
cid  name                      type     notnull  dflt_value  pk
---  ------------------------  -------  -------  ----------  --
0    BookmarkID                TEXT     1                    1 
1    VolumeID                  TEXT     1                    0 
2    ContentID                 TEXT     1                    0 
3    StartContainerPath        TEXT     1                    0 
4    StartContainerChildIndex  INTEGER  1                    0 
5    StartOffset               INTEGER  1                    0 
6    EndContainerPath          TEXT     1                    0 
7    EndContainerChildIndex    INTEGER  1                    0 
8    EndOffset                 INTEGER  1                    0 
9    Text                      TEXT     0                    0 
10   Annotation                TEXT     0                    0 
11   ExtraAnnotationData       BLOB     0                    0 
12   DateCreated               TEXT     0                    0 
13   ChapterProgress           REAL     1        0           0 
14   Hidden                    BOOL     1        0           0 
15   Version                   TEXT     0                    0 
16   DateModified              TEXT     0                    0 
17   Creator                   TEXT     0                    0 
18   UUID                      TEXT     0                    0 
19   UserID                    TEXT     0                    0 
20   SyncTime                  TEXT     0                    0 
21   Published                 BIT      0        false       0 
22   ContextString             TEXT     0                    0 
23   Type                      TEXT     0                    0
```

Here are a couple examples of highlights and notes from a sideloaded book. The `VolumeID` is the `ContentID` from the main book entry in `content`. The `ContentID` in `Bookmark` contains the sub-file where the annotation took place (matching a sub-file `ContentID` from `content`) with some data appended showing exactly where the annotation took place. 
```
sqlite> select VolumeID, ContentID, Text, Annotation, UserID, Type from Bookmark where VolumeID = "file:///mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief History of Humankind - Yuval Noah Harari.kepub.epub";
VolumeID                                                      ContentID                                                     Text                                                          Annotation    UserID                                Type     
------------------------------------------------------------  ------------------------------------------------------------  ------------------------------------------------------------  ------------  ------------------------------------  ---------
file:///mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief Hist  /mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief History of   ABOUT 13.5 BILLION YEARS AGO, MATTER, energy, time and space                d5e94a94-bc32-4b48-b229-6de0c8e31665  highlight
ory of Humankind - Yuval Noah Harari.kepub.epub               Humankind - Yuval Noah Harari.kepub.epub!!OEBPS/Hara_9780771   came into being in what is known as the Big Bang. The story                                                               
                                                              038525_epub_c01_r1.htm                                         of these fundamental features of our universe is called phy                                                               
                                                                                                                            sics.                                                                                                                      

file:///mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief Hist  /mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief History of   About 3.8 billion years ago, on a planet called Earth, certa  Test thought  d5e94a94-bc32-4b48-b229-6de0c8e31665  note     
ory of Humankind - Yuval Noah Harari.kepub.epub               Humankind - Yuval Noah Harari.kepub.epub!!OEBPS/Hara_9780771  in molecules combined to form particularly large and intrica                                                               
                                                              038525_epub_c01_r1.htm                                        te structures called organisms. The story of organisms is ca                                                               
                                                                                                                            lled biology.                                                                                                              
sqlite>
```
There are additional fields which seem to represent the annotation location in tandem with `ContentID` which I will select and display below:
```
sqlite> select VolumeID, ContentID, StartContainerPath, StartContainerChildIndex, StartOffset, EndContainerPath, EndContainerChildIndex, EndOffset, ChapterProgress from Bookmark where VolumeID = "file:///mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief History of Humankind - Yuval Noah Harari.kepub.epub";
VolumeID                                                      ContentID                                                     StartContainerPath  StartContainerChildIndex  StartOffset  EndContainerPath  EndContainerChildIndex  EndOffset  ChapterProgress
------------------------------------------------------------  ------------------------------------------------------------  ------------------  ------------------------  -----------  ----------------  ----------------------  ---------  ---------------
file:///mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief Hist  /mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief History of   span#kobo\.3\.1     -99                       0            span#kobo\.4\.1   -99                     0          0.05           
ory of Humankind - Yuval Noah Harari.kepub.epub               Humankind - Yuval Noah Harari.kepub.epub!!OEBPS/Hara_9780771                                                                                                                                 
                                                              038525_epub_c01_r1.htm                                                                                                                                                                       

file:///mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief Hist  /mnt/onboard/Harari, Yuval Noah/Sapiens_ A Brief History of   span#kobo\.5\.1     -99                       0            span#kobo\.5\.2   -99                     41         0.05           
ory of Humankind - Yuval Noah Harari.kepub.epub               Humankind - Yuval Noah Harari.kepub.epub!!OEBPS/Hara_9780771                                                                                                                                 
                                                              038525_epub_c01_r1.htm                                                                                                                                                                       
sqlite>
```

Here are the same `Bookmark` fields selected for a CWA-loaded book. I highlightex the exact same portion of text for these bookmarks. Even though the ePubs and highlights are the same, the `EndContainerPath` and `EndOffset` slightly differ suggesting the `Bookmark` entries aren't interchangable between books.
```
sqlite> select VolumeID, ContentID, Text, Annotation, UserID, Type from Bookmark where VolumeID = "b38b4bbb-3751-4d27-a4fa-ecd3c19188ee";
VolumeID                              ContentID                                                     Text                                                          Annotation    UserID                                Type     
------------------------------------  ------------------------------------------------------------  ------------------------------------------------------------  ------------  ------------------------------------  ---------
b38b4bbb-3751-4d27-a4fa-ecd3c19188ee  b38b4bbb-3751-4d27-a4fa-ecd3c19188ee!!OEBPS/Hara_97807710385  ABOUT 13.5 BILLION YEARS AGO, MATTER, energy, time and space                d5e94a94-bc32-4b48-b229-6de0c8e31665  highlight
                                      25_epub_c01_r1.htm                                             came into being in what is known as the Big Bang. The story                                                               
                                                                                                     of these fundamental features of our universe is called phy                                                               
                                                                                                    sics.                                                                                                                      

b38b4bbb-3751-4d27-a4fa-ecd3c19188ee  b38b4bbb-3751-4d27-a4fa-ecd3c19188ee!!OEBPS/Hara_97807710385  About 3.8 billion years ago, on a planet called Earth, certa  Test thought  d5e94a94-bc32-4b48-b229-6de0c8e31665  note     
                                      25_epub_c01_r1.htm                                            in molecules combined to form particularly large and intrica                                                               
                                                                                                    te structures called organisms. The story of organisms is ca                                                               
                                                                                                    lled biology.                                                                                                              
sqlite> select VolumeID, ContentID, StartContainerPath, StartContainerChildIndex, StartOffset, EndContainerPath, EndContainerChildIndex, EndOffset, ChapterProgress from Bookmark where VolumeID = "b38b4bbb-3751-4d27-a4fa-ecd3c19188ee";
VolumeID                              ContentID                                                     StartContainerPath  StartContainerChildIndex  StartOffset  EndContainerPath  EndContainerChildIndex  EndOffset  ChapterProgress
------------------------------------  ------------------------------------------------------------  ------------------  ------------------------  -----------  ----------------  ----------------------  ---------  ---------------
b38b4bbb-3751-4d27-a4fa-ecd3c19188ee  b38b4bbb-3751-4d27-a4fa-ecd3c19188ee!!OEBPS/Hara_97807710385  span#kobo\.3\.1     -99                       0            span#kobo\.3\.2   -99                     74         0.05           
                                      25_epub_c01_r1.htm                                                                                                                                                                           

b38b4bbb-3751-4d27-a4fa-ecd3c19188ee  b38b4bbb-3751-4d27-a4fa-ecd3c19188ee!!OEBPS/Hara_97807710385  span#kobo\.5\.1     -99                       0            span#kobo\.5\.2   -99                     41         0.05           
                                      25_epub_c01_r1.htm                                                                                                                                                                           
sqlite> 
```

## ePub File Locations on Kobo

These files seem to be the Calibre-Web/CWA-loaded books bc `6f03d308-6370-4dc6-935b-2aede5cc81c3` and `f6ddfd47-9b66-4cd7-ab60-e478aa5e92a9` align with the `ContentID` for the 2 books I have downloaded from CWA currently.
```
jordan@Jordans-MBP KOBOeReader % ls -la .kobo/kepub
total 5280
drwx------  1 jordan  staff     8192 Jan 12 11:05 .
drwx------  1 jordan  staff     8192 Jan 12 13:54 ..
-rwx------  1 jordan  staff     4096 Jan 12 11:05 ._6f03d308-6370-4dc6-935b-2aede5cc81c3
-rwx------@ 1 jordan  staff  2250952 Jan  9 20:20 6f03d308-6370-4dc6-935b-2aede5cc81c3
-rwx------  1 jordan  staff        0 Dec 17 19:46 8b8442e5-6910-4ad0-b0e4-aaabb3bd1778.temp
-rwx------  1 jordan  staff   423854 Jan  9 19:14 f6ddfd47-9b66-4cd7-ab60-e478aa5e92a9
jordan@Jordans-MBP KOBOeReader %
```
Sideloaded ePub files preside in the root directory of the device in directories according to author:
```
jordan@Jordans-MBP KOBOeReader % ls -la
total 384
drwx------  1 jordan  staff   8192 Jan 12 10:24 .
drwxr-xr-x  4 root    wheel    128 Jan 12 10:24 ..
drwx------  1 jordan  staff   8192 Dec 16  2023 .Spotlight-V100
drwx------  1 jordan  staff   8192 Dec 18 17:03 .add
drwx------  1 jordan  staff   8192 Dec 18 17:03 .adds
drwx------  1 jordan  staff   8192 Dec 16  2023 .adobe-digital-editions
drwx------  1 jordan  staff   8192 Jan 12 10:24 .fseventsd
drwx------  1 jordan  staff   8192 Jan 12 13:54 .kobo
drwx------  1 jordan  staff   8192 Dec 16  2023 .kobo-images
drwx------  1 jordan  staff   8192 Aug  5  2024 Dazai, Osamu
drwx------  1 jordan  staff   8192 Aug 10 21:28 Dolly, Cure
drwx------  1 jordan  staff   8192 Dec 16  2023 Hanh, Thich Nhat
drwx------  1 jordan  staff   8192 Jan 11 16:49 Harari, Yuval Noah
drwx------  1 jordan  staff   8192 Sep 30 00:34 Lamott, Anne
drwx------  1 jordan  staff   8192 Feb 27  2025 Lem, Stanislaw
drwx------  1 jordan  staff   8192 Dec 16  2023 Petzold, Charles
drwx------  1 jordan  staff   8192 Sep 18 00:26 Shelley, Joe & Gibson, Darril
drwx------  1 jordan  staff   8192 Dec 16  2023 Stephenson, Neal
drwx------  1 jordan  staff   8192 Apr 17  2025 Ward, Brian
-rwx------  1 jordan  staff    268 Jan 11 17:05 driveinfo.calibre
-rwx------  1 jordan  staff  39062 Jan 11 17:05 metadata.calibre
jordan@Jordans-MBP KOBOeReader % ls -la "Dazai, Osamu"
total 608
drwx------  1 jordan  staff    8192 Aug  5  2024 .
drwx------  1 jordan  staff    8192 Jan 12 10:24 ..
-rwx------  1 jordan  staff  290486 Aug  5  2024 No Longer Human - Osamu Dazai.kepub.epub
```

## `Shelf` & `ShelfContent` Tables

```
sqlite> select * from ShelfContent;
ShelfName   ContentId                             DateModified          _IsDeleted  _IsSynced
----------  ------------------------------------  --------------------  ----------  ---------
Admin Sync  f95adcc1-8251-4127-a5c3-ff0d2f085862  2026-01-09T19:09:26Z  false       true     
Admin Sync  496b083a-a29b-46ca-8712-ce633e847c0d  2026-01-09T19:09:26Z  false       true     
Admin Sync  f6ddfd47-9b66-4cd7-ab60-e478aa5e92a9  2026-01-09T19:09:26Z  false       true     
Admin Sync  9af831fe-e23c-4c9e-8d41-78fab2ace4c6  2026-01-09T19:09:26Z  false       true     
Admin Sync  e63be623-0080-44d9-8585-b68724aea685  2026-01-09T19:09:26Z  false       true     
Admin Sync  2ca85ca8-d580-493e-94b8-3a62f7b00c0f  2026-01-09T19:09:26Z  false       true     
Admin Sync  e59aa8b4-2103-4e77-97a8-37b406beaf22  2026-01-09T19:09:26Z  false       true     
Admin Sync  6f03d308-6370-4dc6-935b-2aede5cc81c3  2026-01-09T19:09:26Z  false       true     
sqlite> select * from Shelf;
CreationDate          Id                                    InternalName  LastModified          Name        Type     _IsDeleted  _IsVisible  _IsSynced  _SyncTime             LastAccessed        
--------------------  ------------------------------------  ------------  --------------------  ----------  -------  ----------  ----------  ---------  --------------------  --------------------
2026-01-09T18:43:14Z  c2329f55-2e57-4e3f-a87b-46aeb6cb8981  Admin Sync    2026-01-09T18:43:14Z  Admin Sync  UserTag  false       true        true       2026-01-09T20:20:12Z  2026-01-09T18:43:14Z
```