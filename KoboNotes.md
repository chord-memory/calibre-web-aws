# `KoboReader.sqlite` Explained

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

Here are a couple examples of highlights and notes from a sideloaded book. The `VolumeID` is the `ContentID` from the main book entry in `content`. The `ContentID` in `Bookmark` contains the sub-file where the annotation took place (matching a sub-file `ContenteID` from `content`) with some data appended showing exactly where the annotation took place. 
```
sqlite> select VolumeID, ContentID, Text, Annotation, UserID, Type from Bookmark where VolumeID = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" and Type = "highlight" limit 2;
VolumeID                                                      ContentID                                                     Text                                                          Annotation  UserID                                Type     
------------------------------------------------------------  ------------------------------------------------------------  ------------------------------------------------------------  ----------  ------------------------------------  ---------
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  I’ve tried to cover the two major distribution families: Deb              d5e94a94-bc32-4b48-b229-6de0c8e31665  highlight
.kepub.epub                                                   epub!OPS!f06.xhtml#h1-500402f06-0005                          ian (including Ubuntu) and RHEL/Fedora/CentOS. I’ve also foc                                                             
                                                                                                                            used on desktop and server installations. A significant amou                                                             
                                                                                                                            nt of material carries over into embedded systems, such as A                                                             
                                                                                                                            ndroid and OpenWRT, but it’s up to you to discover the diffe                                                             
                                                                                                                            rences on those platforms.                                                                                               

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  The $ is the prompt for a regular user account. If you see a              d5e94a94-bc32-4b48-b229-6de0c8e31665  highlight
.kepub.epub                                                   epub!OPS!f06.xhtml#h1-500402f06-0005                           # as a prompt, you need to be superuser.                                                                                
sqlite> select VolumeID, ContentID, Text, Annotation, UserID, Type from Bookmark where VolumeID = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" and Type = "note" limit 2; 
VolumeID                                                      ContentID                                                     Text                                                          Annotation                                                    UserID                                Type
------------------------------------------------------------  ------------------------------------------------------------  ------------------------------------------------------------  ------------------------------------------------------------  ------------------------------------  ----
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  Each piece of time—called a time slice—gives a process enoug  What would be a "task" in this context?                       d5e94a94-bc32-4b48-b229-6de0c8e31665  note
.kepub.epub                                                   epub!OPS!c01.xhtml#h2-500402c01-0001                          h time for significant computation (and indeed, a process of                                                                                                          
                                                                                                                            ten finishes its current task during a single slice). Howeve                                                                                                          
                                                                                                                            r, because the slices are so small, humans can’t perceive th                                                                                                          
                                                                                                                            em, and the system appears to be running multiple processes                                                                                                           
                                                                                                                            at the same time (a capability known as multitasking).                                                                                                                

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  When a process calls fork(), the kernel creates a nearly ide  Same memory & code, parent & child. When child finishes, par  d5e94a94-bc32-4b48-b229-6de0c8e31665  note
.kepub.epub                                                   epub!OPS!c01.xhtml#h2-500402c01-0004                          ntical copy of the process.                                   ent takes over. Child usually replaced w exec. See graphic                                              
sqlite> 
```
There are additional fields which seem to represent the annotation location in tandem with `ContentID` which I will select and display below:
```
sqlite> select VolumeID, ContentID, StartContainerPath, StartContainerChildIndex, StartOffset, EndContainerPath, EndContainerChildIndex, EndOffset, ChapterProgress from Bookmark where VolumeID = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" and Type = "highlight" limit 2;
VolumeID                                                      ContentID                                                     StartContainerPath  StartContainerChildIndex  StartOffset  EndContainerPath  EndContainerChildIndex  EndOffset  ChapterProgress  
------------------------------------------------------------  ------------------------------------------------------------  ------------------  ------------------------  -----------  ----------------  ----------------------  ---------  -----------------
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  span#kobo\.35\.2    -99                       84           span#kobo\.35\.5  -99                     164        0.666666666666667
.kepub.epub                                                   epub!OPS!f06.xhtml#h1-500402f06-0005                                                                                                                                                           

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  span#kobo\.21\.2    -99                       0            span#kobo\.25\.1  -99                     39         0.666666666666667
.kepub.epub                                                   epub!OPS!f06.xhtml#h1-500402f06-0005                                                                                                                                                           
sqlite> select VolumeID, ContentID, StartContainerPath, StartContainerChildIndex, StartOffset, EndContainerPath, EndContainerChildIndex, EndOffset, ChapterProgress from Bookmark where VolumeID = "file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.epub" and Type = "note" limit 2;
VolumeID                                                      ContentID                                                     StartContainerPath  StartContainerChildIndex  StartOffset  EndContainerPath   EndContainerChildIndex  EndOffset  ChapterProgress  
------------------------------------------------------------  ------------------------------------------------------------  ------------------  ------------------------  -----------  -----------------  ----------------------  ---------  -----------------
file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  span#kobo\.100\.1   -99                       0            span#kobo\.105\.1  -99                     0          0.526315789473684
.kepub.epub                                                   epub!OPS!c01.xhtml#h2-500402c01-0001                                                                                                                                                            

file:///mnt/onboard/Ward, Brian/How Linux Works - Brian Ward  /mnt/onboard/Ward, Brian/How Linux Works - Brian Ward.kepub.  span#kobo\.152\.1   -99                       1            span#kobo\.154\.1  -99                     60         0.684210526315789
.kepub.epub                                                   epub!OPS!c01.xhtml#h2-500402c01-0004                                                                                                                                                            
sqlite>
```
TODO: Add Calibre-Web/CWA-loaded Bookmark entries