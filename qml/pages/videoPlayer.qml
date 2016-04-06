import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.0
import Sailfish.Media 1.0
import "helper"
import "fileman"

Page {
    id: videoPlayerPage
    objectName: "videoPlayerPage"
    allowedOrientations: Orientation.All

    focus: true

    property QtObject dataContainer

    property string videoDuration: {
        if (videoPoster.duration > 3599) return Format.formatDuration(videoPoster.duration, Formatter.DurationLong)
        else return Format.formatDuration(videoPoster.duration, Formatter.DurationShort)
    }
    property string videoPosition: {
        if (videoPoster.position > 3599) return Format.formatDuration(videoPoster.position, Formatter.DurationLong)
        else return Format.formatDuration(videoPoster.position, Formatter.DurationShort)
    }
    property string originalUrl: dataContainer.originalUrl
    property string streamUrl: dataContainer.streamUrl
    property bool youtubeDirect: dataContainer.youtubeDirect
    property bool isYtUrl: dataContainer.isYtUrl
    property string streamTitle: dataContainer.streamTitle
    property string title: videoPoster.player.metaData.title ? videoPoster.player.metaData.title : ""
    property string artist: videoPoster.player.metaData.albumArtist ? videoPoster.player.metaData.albumArtist : ""
    property int subtitlesSize: dataContainer.subtitlesSize
    property bool boldSubtitles: dataContainer.boldSubtitles
    property string subtitlesColor: dataContainer.subtitlesColor
    property bool enableSubtitles: dataContainer.enableSubtitles
    property variant currentVideoSub: []
    property string url720p: dataContainer.url720p
    property string url480p: dataContainer.url480p
    property string url360p: dataContainer.url360p
    property string url240p: dataContainer.url240p
    property string ytQual: dataContainer.ytQual
    property bool liveView: true
    property Page dPage
    property bool autoplay: dataContainer.autoplay
    property bool savedPosition: false
    property string savePositionMsec
    property string subtitleUrl
    property bool subtitleSolid: dataContainer.subtitleSolid
    property bool isPlaylist: dataContainer.isPlaylist
    property bool isPlayClicked: false

    property alias showTimeAndTitle: showTimeAndTitle
    property alias pulley: pulley
    property alias onlyMusic: onlyMusic
    property alias videoPoster: videoPoster

    Component.onCompleted: {
        if (autoplay) {
            //console.debug("[videoPlayer.qml] Autoplay activated for url: " + videoPoster.source);
            videoPoster.play();
            // TODO: Workaround somehow toggleControls() has a racing condition with something else
            pulley.visible = false;
            showNavigationIndicator = false;
        }
    }

    Component.onDestruction: {
        console.debug("Destruction of videoplayer")
        var sourcePath = mediaPlayer.source.toString();
        if (sourcePath.match("^file://")) {
            //console.debug("[videoPlayer.qml] Destruction going on so write : " + mediaPlayer.source + " with timecode: " + mediaPlayer.position + " to db")
            DB.addPosition(sourcePath,mediaPlayer.position);
        }
        mediaPlayer.stop();
        mediaPlayer.source = "";
        mediaPlayer.play();
        mediaPlayer.stop();
        gc();
        video.destroy();
        pageStack.popAttached();
    }

//    onStatusChanged: {
//        if (status == PageStatus.Deactivating) {
//            //console.debug("VidePlayer page deactivated");
//            mediaPlayer.stop();
//            video.destroy();
//        }
//    }

    onStreamUrlChanged: {
        if (errorDetail.visible && errorTxt.visible) { errorDetail.visible = false; errorTxt.visible = false }
        videoPoster.showControls();
//        dataContainer.streamTitle = ""  // Reset Stream Title here
//        dataContainer.ytQual = ""
        if (YT.checkYoutube(streamUrl)=== true) {
            //console.debug("[videoPlayer.qml] Youtube Link detected loading Streaming URLs")
            // Reset Stream urls
            dataContainer.url240p = ""
            dataContainer.url360p = ""
            dataContainer.url480p = ""
            dataContainer.url720p = ""
            YT.getYoutubeTitle(streamUrl);
            var ytID = YT.getYtID(streamUrl);
            YT.getYoutubeStream(ytID);
        }
        else if (YT.checkYoutube(originalUrl) === true) {
            //console.debug("[videoPlayer.qml] Loading Youtube Title from original URL")
            YT.getYoutubeTitle(originalUrl);
        }
        if (dataContainer.streamTitle == "") dataContainer.streamTitle = mainWindow.findBaseName(streamUrl)
        dataContainer.ytdlStream = false

        if (streamUrl.toString().match("^file://")) {
            savePositionMsec = DB.getPosition(streamUrl.toString());
            //console.debug("[videoPlayer.qml] streamUrl= " + streamUrl + " savePositionMsec= " + savePositionMsec + " streamUrl.length = " + streamUrl.length);
            if (savePositionMsec !== "Not Found") savedPosition = true;
            else savedPosition = false;
        }
    }

    onStreamTitleChanged: {
        if (streamTitle != "") {
            //Write into history database
            DB.addHistory(streamUrl,streamTitle);
            // Don't forgt to write it to the List aswell
            mainWindow.firstPage.add2History(streamUrl,streamTitle);
        }
    }

    Rectangle {
        id: headerBg
        width:urlHeader.width
        height: urlHeader.height
        visible: {
            if (urlHeader.visible || titleHeader.visible) return true
            else return false
        }
        gradient: Gradient {
            GradientStop { position: 0.0; color: "black" }
            GradientStop { position: 1.0; color: "transparent" } //Theme.highlightColor} // Black seems to look and work better
        }
    }

    PageHeader {
        id: urlHeader
        title: mainWindow.findBaseName(streamUrl)
        _titleItem.color: "white"
        visible: {
            if (titleHeader.visible == false && pulley.visible && mainWindow.applicationActive) return true
            else return false
        }
        _titleItem.font.pixelSize: mainWindow.applicationActive ? Theme.fontSizeMedium : Theme.fontSizeHuge
        states: [
            State {
                name: "cover"
                PropertyChanges {
                    target: urlHeader
                    visible: true
                }
            }
        ]
    }
    PageHeader {
        id: titleHeader
        _titleItem.color: "white"
        title: streamTitle
        visible: {
            if (streamTitle != "" && pulley.visible && mainWindow.applicationActive) return true
            else return false
        }
        _titleItem.font.pixelSize: mainWindow.applicationActive ? Theme.fontSizeMedium : Theme.fontSizeHuge
        states: [
            State {
                name: "cover"
                PropertyChanges {
                    target: titleHeader
                    visible: true
                }
            }
        ]
    }

    function videoPauseTrigger() {
        // this seems not to work somehow
        if (videoPoster.player.playbackState == MediaPlayer.PlayingState) videoPoster.player.pause();
        else if (videoPoster.source.toString().length !== 0) videoPoster.player.play();
        if (videoPoster.controls.opacity === 0.0) videoPoster.toggleControls();

    }

    SilicaFlickable {
        id: flick
        anchors.fill: parent

        // PullDownMenu and PushUpMenu must be declared in SilicaFlickable, SilicaListView or SilicaGridView
        PullDownMenu {
            id: pulley
            MenuItem {
                id: ytMenuItem
                text: qsTr("Download Youtube Video")
                visible: {
                    if ((/^http:\/\/ytapi.com/).test(mainWindow.firstPage.streamUrl)) return true
                    else if (mainWindow.firstPage.isYtUrl) return true
                    else return false
                }
                //onClicked: pageStack.push(Qt.resolvedUrl("DownloadManager.qml"), {"downloadUrl": streamUrl, "downloadName": streamTitle});
                // Alternatively use direct youtube url instead of ytapi for downloads (ytapi links not always download with download manager)
                onClicked: {
                    // Filter out all chars that might stop the download manager from downloading the file
                    // Illegal chars: `~!@#$%^&*()-=+\|/?.>,<;:'"[{]}
                    //console.debug("[FileDetails -> Download YT Video]: " + mainWindow.firstPage.youtubeDirectUrl)
                    mainWindow.firstPage.streamTitle = YT.getDownloadableTitleString(mainWindow.firstPage.streamTitle)
                    pageStack.push(Qt.resolvedUrl("ytQualityChooser.qml"), {"streamTitle": streamTitle, "url720p": url720p, "url480p": url480p, "url360p": url360p, "url240p": url240p, "ytDownload": true});
                }
            }
            MenuItem {
                text: qsTr("Download")
                visible: {
                    if ((/^https?:\/\/.*$/).test(mainWindow.firstPage.streamUrl) && ytMenuItem.visible == false) return true
                    else return false
                }
                //onClicked: pageStack.push(Qt.resolvedUrl("DownloadManager.qml"), {"downloadUrl": streamUrl, "downloadName": streamTitle});
                // Alternatively use direct youtube url instead of ytapi for downloads (ytapi links not always download with download manager)
                onClicked: {
                    // Filter out all chars that might stop the download manager from downloading the file
                    // Illegal chars: `~!@#$%^&*()-=+\|/?.>,<;:'"[{]}
                    //console.debug("[FileDetails -> Download YT Video]: " + mainWindow.firstPage.youtubeDirectUrl)
                    mainWindow.firstPage.streamTitle = YT.getDownloadableTitleString(mainWindow.firstPage.streamTitle)
                    pageStack.push(Qt.resolvedUrl("DownloadManager.qml"), {"downloadName": streamTitle, "downloadUrl": streamUrl});
                }
            }
            MenuItem {
                text: qsTr("Add to bookmarks")
                visible: {
                    if (mainWindow.firstPage.streamTitle != "" || mainWindow.firstPage.streamUrl != "") return true
                    else return false
                }
                onClicked: {
                    if (mainWindow.firstPage.streamTitle != "") mainWindow.modelBookmarks.addBookmark(mainWindow.firstPage.streamUrl,mainWindow.firstPage.streamTitle)
                    else mainWindow.modelBookmarks.addBookmark(mainWindow.firstPage.streamUrl,mainWindow.findBaseName(mainWindow.firstPage.streamUrl))
                }
            }
            MenuItem {
                text: qsTr("Load Subtitle")
                onClicked: pageStack.push(openSubsComponent)
            }
            MenuItem {
                text: qsTr("Play from last known position")
                visible: {
                    savedPosition
                }
                onClicked: {
                    if (mediaPlayer.playbackState != MediaPlayer.PlayingState) videoPoster.play();
                    mediaPlayer.seek(savePositionMsec)
                }
            }
        }

        Image {
            id: onlyMusic
            anchors.centerIn: parent
            source: Qt.resolvedUrl("images/audio.png")
            opacity: 0.0
            Behavior on opacity { FadeAnimation { } }
            width: parent.width / 1.25
            height: width
        }

        ProgressCircle {
            id: progressCircle

            anchors.centerIn: parent
            visible: false

            Timer {
                interval: 32
                repeat: true
                onTriggered: progressCircle.value = (progressCircle.value + 0.005) % 1.0
                running: visible
            }
        }

        Loader {
            id: subTitleLoader
            active: enableSubtitles
            sourceComponent: subItem
            anchors.fill: parent
        }

        Component {
            id: subItem
            SubtitlesItem {
                id: subtitlesText
                anchors { fill: parent; margins: videoPlayerPage.inPortrait ? 10 : 50 }
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignBottom
                pixelSize: subtitlesSize
                bold: boldSubtitles
                color: subtitlesColor
                visible: (enableSubtitles) && (currentVideoSub) ? true : false
                isSolid: subtitleSolid
            }
        }

        Component {
            id: openSubsComponent
            OpenDialog {
                onOpenFile: {
                    subtitleUrl = path
                    pageStack.pop()
                }
            }
        }

        Rectangle {
            color: "black"
            opacity: 0.60
            anchors.fill: parent
            visible: {
                if (errorBox.visible) return true;
                else return false;
            }
        }

        Column {
            id: errorBox
            anchors.top: parent.top
            anchors.topMargin: 65
            spacing: 15
            width: parent.width
            height: parent.height
            z:99
            visible: {
                if (errorTxt.text !== "" || errorDetail.text !== "" ) return true;
                else return false;
            }
            Label {
                // TODO: seems only show error number. Maybe disable in the future
                id: errorTxt
                text: ""

                //            anchors.top: parent.top
                //            anchors.topMargin: 65
                font.bold: true
                onTextChanged: {
                    if (text !== "") visible = true;
                }
            }


            TextArea {
                id: errorDetail
                text: ""
                width: parent.width
                height: parent.height / 2.5
                anchors.horizontalCenter: parent.horizontalCenter
                font.bold: false
                onTextChanged: {
                    if (text !== "") visible = true;
                }
                background: null
                readOnly: true
            }
        }
        Button {
            text: qsTr("Dismiss")
            onClicked: {
                errorTxt.text = ""
                errorDetail.text = ""
                errorBox.visible = false
            }
            visible: errorBox.visible
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.paddingLarge
            z: videoPoster.z + 1
        }

        Item {
            id: mediaItem
            property bool active : true
            visible: active && mainWindow.applicationActive
            anchors.fill: parent

            VideoPoster {
                id: videoPoster
                width: videoPlayerPage.orientation === Orientation.Portrait ? Screen.width : Screen.height
                height: videoPlayerPage.height

                player: mediaPlayer

                //duration: videoDuration
                active: mediaItem.active
                source: streamUrl
                onSourceChanged: {
                    player.stop();
                    //play();  // autoPlay TODO: add config for it
                    position = 0;
                    player.seek(0);
                    //console.debug("Source changed to " + source)
                }
                //source: "file:///home/nemo/Videos/eva.mp4"
                //source: "http://netrunnerlinux.com/vids/default-panel-script.mkv"
                //source: "http://www.ytapi.com/?vid=lfAixpkzcBQ&format=direct"

                onPlayClicked: {
                    toggleControls();
                    if (enableSubtitles) {
                        subTitleLoader.item.getSubtitles(subtitleUrl);
                    }
                    isPlayClicked = true
                }

                function toggleControls() {
                    //console.debug("Controls Opacity:" + controls.opacity);
                    if (controls.opacity === 0.0) {
                        //console.debug("Show controls");
                        controls.opacity = 1.0;
                    }
                    else {
                        //console.debug("Hide controls");
                        controls.opacity = 0.0;
                    }
                    videoPlayerPage.showNavigationIndicator = !videoPlayerPage.showNavigationIndicator
                    pulley.visible = !pulley.visible
                }

                function hideControls() {
                    controls.opacity = 0.0
                    pulley.visible = false
                    videoPlayerPage.showNavigationIndicator = false
                }

                function showControls() {
                    controls.opacity = 1.0
                    pulley.visible = true
                    videoPlayerPage.showNavigationIndicator = true
                }


                onClicked: {
                    if (drawer.open) drawer.open = false
                    else {
                        if (mediaPlayer.playbackState == MediaPlayer.PlayingState) {
                            //console.debug("Mouse values:" + mouse.x + " x " + mouse.y)
                            var middleX = width / 2
                            var middleY = height / 2
                            //console.debug("MiddleX:" + middleX + " MiddleY:"+middleY + " mouse.x:"+mouse.x + " mouse.y:"+mouse.y)
                            if ((mouse.x >= middleX - 64 && mouse.x <= middleX + 64) && (mouse.y >= middleY - 64 && mouse.y <= middleY + 64)) {
                                mediaPlayer.pause();
                                if (controls.opacity === 0.0) toggleControls();
                                progressCircle.visible = false;
                                if (! mediaPlayer.seekable) mediaPlayer.stop();
                                isPlayClicked = false
                            }
                            else {
                                toggleControls();
                            }
                        } else {
                            //mediaPlayer.play()
                            //console.debug("clicked something else")
                            toggleControls();
                        }
                    }
                }
//                onPressAndHold: {
//                    //console.debug("[Press and Hold detected]")
//                    if (! drawer.open) drawer.open = true
//                }
                onPositionChanged: {
                    if ((enableSubtitles) && (currentVideoSub)) subTitleLoader.item.checkSubtitles()
                }
            }
        }
    }
    Drawer {
        id: drawer
        width: parent.width
        height: parent.height
        anchors.bottom: parent.bottom
        dock: Dock.Bottom
        foreground: flick
        backgroundSize: {
            if (videoPlayerPage.orientation === Orientation.Portrait) return parent.height / 8
            else return parent.height / 6
        }
        background: Rectangle {
            anchors.fill: parent
            anchors.bottom: parent.bottom
            color: Theme.secondaryHighlightColor
            Button {
                id: ytDownloadBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingMedium
                text: "Download video"
                visible: {
                    if ((/^http:\/\/ytapi.com/).test(streamUrl)) return true
                    else if (isYtUrl) return true
                    else return false
                }
                // Alternatively use direct youtube url instead of ytapi for downloads (ytapi links not always download with download manager)
                onClicked: {
                    // Filter out all chars that might stop the download manager from downloading the file
                    // Illegal chars: `~!@#$%^&*()-=+\|/?.>,<;:'"[{]}
                    streamTitle = YT.getDownloadableTitleString(streamTitle)
                    pageStack.push(Qt.resolvedUrl("ytQualityChooser.qml"), {"streamTitle": streamTitle, "url720p": url720p, "url480p": url480p, "url360p": url360p, "url240p": url240p, "ytDownload": true});
                    drawer.open = !drawer.open
                }
            }
            Button {
                id: add2BookmarksBtn
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingMedium
                text : "Add to bookmarks"
                visible: {
                    if (streamTitle != "" || streamUrl != "") return true
                    else return false
                }
                onClicked: {
                    if (streamTitle != "" && !youtubeDirect) mainWindow.modelBookmarks.addBookmark(streamUrl,streamTitle)
                    else if (streamTitle != "" && youtubeDirect) mainWindow.modelBookmarks.addBookmark(originalUrl,streamTitle)
                    else if (!youtubeDirect) mainWindow.modelBookmarks.addBookmark(streamUrl,mainWindow.findBaseName(streamUrl))
                    else mainWindow.modelBookmarks.addBookmark(originalUrl,mainWindow.findBaseName(originalUrl))
                    drawer.open = !drawer.open
                }
            }
        }

    }

    children: [

        // Always use a black background
        Rectangle {
            anchors.fill: parent
            color: "black"
            //visible: video.visible
        },

        VideoOutput {
            id: video
            anchors.fill: parent

            source: MediaPlayer {
                id: mediaPlayer

                function loadMetaDataPage() {
                    //console.debug("Loading metadata page")
                    var mDataTitle;
                    //console.debug(metaData.title)
                    if (streamTitle != "") mDataTitle = streamTitle
                    else mDataTitle = mainWindow.findBaseName(streamUrl)
                    //console.debug("[mDataTitle]: " + mDataTitle)
                    dPage = pageStack.pushAttached(Qt.resolvedUrl("FileDetails.qml"), {
                                                       filename: streamUrl,
                                                       title: mDataTitle,
                                                       artist: metaData.albumArtist,
                                                       videocodec: metaData.videoCodec,
                                                       resolution: metaData.resolution,
                                                       videobitrate: metaData.videoBitRate,
                                                       framerate: metaData.videoFrameRate,
                                                       audiocodec: metaData.audioCodec,
                                                       audiobitrate: metaData.audioBitRate,
                                                       samplerate: metaData.sampleRate,
                                                       copyright: metaData.copyright,
                                                       date: metaData.date,
                                                       size: metaData.size
                                                   });
                }

                onDurationChanged: {
                    //console.debug("Duration(msec): " + duration);
                    videoPoster.duration = (duration/1000);
                    if (hasAudio === true && hasVideo === false) onlyMusic.opacity = 1.0
                    else onlyMusic.opacity = 0.0;
                }
                onStatusChanged: {
                    //errorTxt.visible = false     // DEBUG: Always show errors for now
                    //errorDetail.visible = false
                    //console.debug("[videoPlayer.qml]: mediaPlayer.status: " + mediaPlayer.status)
                    if (mediaPlayer.status === MediaPlayer.Loading || mediaPlayer.status === MediaPlayer.Buffering || mediaPlayer.status === MediaPlayer.Stalled) progressCircle.visible = true;
                    else if (mediaPlayer.status === MediaPlayer.EndOfMedia) {
                        videoPoster.showControls();
                        if (isPlaylist && mainWindow.modelPlaylist.isNext()) {
                            // reset
                            streamUrl = ""
                            streamTitle = ""
                            stop()
                            // before load new
                            streamUrl = mainWindow.modelPlaylist.next() ;
                            source = streamUrl
                            videoPoster.player.play();
                        }
                    }
                    else  { progressCircle.visible = false; loadMetaDataPage(); }
                    if (metaData.title) dPage.title = metaData.title
                }
                onError: {
                    // Just a little help
        //            MediaPlayer.NoError - there is no current error.
        //            MediaPlayer.ResourceError - the video cannot be played due to a problem allocating resources.
        //            MediaPlayer.FormatError - the video format is not supported.
        //            MediaPlayer.NetworkError - the video cannot be played due to network issues.
        //            MediaPlayer.AccessDenied - the video cannot be played due to insufficient permissions.
        //            MediaPlayer.ServiceMissing - the video cannot be played because the media service could not be instantiated.
                    if (error == MediaPlayer.ResourceError) errorTxt.text = "Ressource Error";
                    else if (error == MediaPlayer.FormatError) errorTxt.text = "Format Error";
                    else if (error == MediaPlayer.NetworkError) errorTxt.text = "Network Error";
                    else if (error == MediaPlayer.AccessDenied) errorTxt.text = "Access Denied Error";
                    else if (error == MediaPlayer.ServiceMissing) errorTxt.text = "Media Service Missing Error";
                    //errorTxt.text = error;
                    // Prepare user friendly advise on error
                    errorDetail.text = errorString;
                    if (error == MediaPlayer.ResourceError) errorDetail.text += qsTr("\nThe video cannot be played due to a problem allocating resources.\n\
On Youtube Videos please make sure to be logged in. Some videos might be geoblocked or require you to be logged into youtube.")
                    else if (error == MediaPlayer.FormatError) errorDetail.text += qsTr("\nThe audio and or video format is not supported.")
                    else if (error == MediaPlayer.NetworkError) errorDetail.text += qsTr("\nThe video cannot be played due to network issues.")
                    else if (error == MediaPlayer.AccessDenied) errorDetail.text += qsTr("\nThe video cannot be played due to insufficient permissions.")
                    else if (error == MediaPlayer.ServiceMissing) errorDetail.text += qsTr("\nThe video cannot be played because the media service could not be instantiated.")
                    errorBox.visible = true;
                    /* Avoid MediaPlayer undefined behavior */
                    stop();
                }
                onBufferProgressChanged: {
                    if (bufferProgress == 1.0 && isPlayClicked) play()
                }
            }

            visible: mediaPlayer.status >= MediaPlayer.Loaded && mediaPlayer.status <= MediaPlayer.EndOfMedia
            width: parent.width
            height: parent.height
            anchors.centerIn: videoPlayerPage

            ScreenBlank {
                suspend: mediaPlayer.playbackState == MediaPlayer.PlayingState
            }
        }
    ]

    // Need some more time to figure that out completely
    Timer {
        id: showTimeAndTitle
        property int count: 0
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            ++count
            if (count >= 5) {
                stop()
                coverTime.fadeOut.start()
                urlHeader.state = ""
                titleHeader.state = ""
                count = 0
            } else {
                coverTime.visible = true
                if (title.toString().length !== 0 && !mainWindow.applicationActive) titleHeader.state = "cover";
                else if (streamUrl.toString().length !== 0 && !mainWindow.applicationActive) urlHeader.state = "cover";
            }
        }
    }

    Rectangle {
        width: parent.width
        height: Theme.fontSizeHuge
        y: coverTime.y + 10
        color: "black"
        opacity: 0.4
        visible: coverTime.visible
    }

    Item {
        id: coverTime
        property alias fadeOut: fadeout
        //visible: !mainWindow.applicationActive && liveView
        visible: false
        onVisibleChanged: {
            if (visible) fadein.start()
        }
        anchors.top: titleHeader.bottom
        anchors.topMargin: 15
        x : (parent.width / 2) - ((curPos.width/2) + (dur.width/2))
        NumberAnimation {
            id: fadein
            target: coverTime
            property: "opacity"
            easing.type: Easing.InOutQuad
            duration: 500
            from: 0
            to: 1
        }
        NumberAnimation {
            id: fadeout
            target: coverTime
            property: "opacity"
            duration: 500
            easing.type: Easing.InOutQuad
            from: 1
            to: 0
            onStopped: coverTime.visible = false;
        }
        Label {
            id: dur
            text: videoDuration
            anchors.left: curPos.right
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeHuge
            font.bold: true
        }
        Label {
            id: curPos
            text: videoPosition + " / "
            color: Theme.highlightColor
            font.pixelSize: Theme.fontSizeHuge
            font.bold: true
        }
    }

    Keys.onPressed: {
        if (event.key == Qt.Key_Space) videoPauseTrigger();
        if (event.key == Qt.Key_Left && mediaPlayer.seekable) {
            mediaPlayer.seek(mediaPlayer.position - 5000)
        }
        if (event.key == Qt.Key_Right && mediaPlayer.seekable) {
            mediaPlayer.seek(mediaPlayer.position + 5000)
        }
    }

    CoverActionList {
        id: coverActionPlay
        enabled: liveView && !isPlaylist

        //        CoverAction {
        //            iconSource: "image://theme/icon-cover-next"
        //        }

        CoverAction {
            iconSource: {
                if (videoPoster.player.playbackState === MediaPlayer.PlayingState) return "image://theme/icon-cover-pause"
                else return "image://theme/icon-cover-play"
            }
            onTriggered: {
                //console.debug("Pause triggered");
                videoPauseTrigger();
                if (!showTimeAndTitle.running) showTimeAndTitle.start();
                else showTimeAndTitle.count = 0;
                videoPoster.hideControls();
            }
        }
    }
    CoverActionList {
        id: coverActionPlayNext
        enabled: liveView && mainWindow.modelPlaylist.isNext() && isPlaylist

        //        CoverAction {
        //            iconSource: "image://theme/icon-cover-next"
        //        }

        CoverAction {
            iconSource: {
                if (videoPoster.player.playbackState === MediaPlayer.PlayingState) return "image://theme/icon-cover-pause"
                else return "image://theme/icon-cover-play"
            }
            onTriggered: {
                //console.debug("Pause triggered");
                videoPauseTrigger();
                if (!showTimeAndTitle.running) showTimeAndTitle.start();
                else showTimeAndTitle.count = 0;
                videoPoster.hideControls();
            }
        }
        CoverAction {
            iconSource: "image://theme/icon-cover-next-song"
            onTriggered: {
                // reset
                streamUrl = ""
                streamTitle = ""
                mediaPlayer.stop()
                // before load new
                streamUrl = mainWindow.modelPlaylist.next() ;
                mediaPlayer.source = streamUrl
                videoPoster.player.play();
            }
        }
    }
}
