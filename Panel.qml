import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var geometryPlaceholder: panelContainer
  readonly property bool allowAttach: true
  property real contentPreferredWidth: 920 * Style.uiScaleRatio

  readonly property real panelTileHeight: 260 * Style.uiScaleRatio
  readonly property real panelMaxBodyHeight: 600 * Style.uiScaleRatio
  readonly property int panelGridRows: camerasModel.count > 0 ? Math.ceil(camerasModel.count / gridColumns) : 0
  readonly property real panelGridIdealHeight: panelGridRows * panelTileHeight + Math.max(0, panelGridRows - 1) * Style.marginM
  readonly property real panelScrollHeight: camerasModel.count > 0 ? Math.min(panelGridIdealHeight, panelMaxBodyHeight) : 0

  property real contentPreferredHeight: Style.marginL * 2 + panelHeaderRow.implicitHeight + (panelErrorText.visible ? Style.marginM + panelErrorText.implicitHeight : 0) + (camerasModel.count > 0 ? Style.marginM + panelScrollHeight : 0) + (frigateBaseUrl.length > 0 ? Style.marginM + panelStatsRow.implicitHeight : 0)

  anchors.fill: parent

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property string frigateBaseUrl: normalizeUrl(cfg.frigateBaseUrl ?? defaults.frigateBaseUrl ?? "")
  readonly property bool useMjpeg: (cfg.useMjpeg ?? defaults.useMjpeg ?? false) === true
  readonly property int snapshotIntervalMs: Math.max(200, cfg.snapshotIntervalMs ?? defaults.snapshotIntervalMs ?? 750)
  readonly property string authToken: (cfg.httpAuthToken ?? defaults.httpAuthToken ?? "").trim()
  readonly property int gridColumns: Math.max(1, Math.min(4, cfg.gridColumns ?? defaults.gridColumns ?? 2))
  readonly property bool cameraBlacklistEnabled: (cfg.cameraBlacklistEnabled ?? defaults.cameraBlacklistEnabled ?? true) === true

  readonly property bool mjpegAllowed: useMjpeg && authToken.length === 0

  ListModel {
    id: camerasModel
  }

  property string loadError: ""
  property bool mjpegFallbackNotified: false

  property string statsCpuDisplay: "—"
  property string statsGpuDisplay: "—"

  property string expandedCameraName: ""
  property bool expandedMjpegFailed: false
  property int expandedSnapshotBust: 0

  property real expandedZoom: 1.0
  property real expandedPanX: 0
  property real expandedPanY: 0

  readonly property real expandedZoomMin: 1.0
  readonly property real expandedZoomMax: 5.0
  readonly property bool expandedShowSnapshot: !root.mjpegAllowed || expandedMjpegFailed || root.authToken.length > 0

  function resetExpandViewTransform() {
    root.expandedZoom = root.expandedZoomMin;
    root.expandedPanX = 0;
    root.expandedPanY = 0;
  }

  function clampExpandPan() {
    if (!expandStreamViewport || expandStreamViewport.width <= 1 || expandStreamViewport.height <= 1) {
      return;
    }
    var w = expandStreamViewport.width;
    var h = expandStreamViewport.height;
    var z = root.expandedZoom;
    if (z <= root.expandedZoomMin + 0.001) {
      root.expandedZoom = root.expandedZoomMin;
      root.expandedPanX = 0;
      root.expandedPanY = 0;
      return;
    }
    var minX = w * (1 - z);
    var minY = h * (1 - z);
    root.expandedPanX = Math.min(0, Math.max(minX, root.expandedPanX));
    root.expandedPanY = Math.min(0, Math.max(minY, root.expandedPanY));
  }

  function applyExpandZoomAt(localX, localY, factor) {
    if (!expandStreamViewport || expandStreamViewport.width <= 0) {
      return;
    }
    var oldZ = root.expandedZoom;
    var newZ = Math.max(root.expandedZoomMin, Math.min(root.expandedZoomMax, oldZ * factor));
    if (Math.abs(newZ - oldZ) < 0.0001) {
      return;
    }
    var cx = (localX - root.expandedPanX) / oldZ;
    var cy = (localY - root.expandedPanY) / oldZ;
    root.expandedZoom = newZ;
    root.expandedPanX = localX - cx * newZ;
    root.expandedPanY = localY - cy * newZ;
    clampExpandPan();
  }

  function openExpandedCam(name) {
    root.expandedMjpegFailed = false;
    root.expandedSnapshotBust = 0;
    resetExpandViewTransform();
    root.expandedCameraName = String(name || "");
  }

  function closeExpanded() {
    root.expandedCameraName = "";
    resetExpandViewTransform();
  }

  function normalizeUrl(u) {
    var s = (u || "").trim();
    while (s.endsWith("/")) {
      s = s.slice(0, -1);
    }
    return s;
  }

  function openFrigateDashboard() {
    var u = root.frigateBaseUrl;
    if (!u || u.length === 0) {
      ToastService.showError(pluginApi?.tr("panel.dashboard.noUrl") ?? "Set Frigate URL in settings first.");
      return;
    }
    Quickshell.execDetached(["xdg-open", u]);
  }

  function bytesToBase64(buffer) {
    var bytes = new Uint8Array(buffer);
    var binary = "";
    for (var i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i]);
    }
    if (typeof Qt !== "undefined" && Qt.btoa) {
      return Qt.btoa(binary);
    }
    var lookup = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var out = "";
    for (var j = 0; j < binary.length; j += 3) {
      var c1 = binary.charCodeAt(j);
      var c2 = j + 1 < binary.length ? binary.charCodeAt(j + 1) : 0;
      var c3 = j + 2 < binary.length ? binary.charCodeAt(j + 2) : 0;
      var triplet = (c1 << 16) | (c2 << 8) | c3;
      var pad = j + 2 >= binary.length ? (j + 1 >= binary.length ? 2 : 1) : 0;
      out += lookup.charAt((triplet >> 18) & 63);
      out += lookup.charAt((triplet >> 12) & 63);
      out += pad >= 2 ? "=" : lookup.charAt((triplet >> 6) & 63);
      out += pad >= 1 ? "=" : lookup.charAt(triplet & 63);
    }
    return out;
  }

  function statsGpuUsageString(gpuEntry) {
    if (!gpuEntry || typeof gpuEntry !== "object") {
      return "";
    }
    var v = String(gpuEntry.gpu !== undefined ? gpuEntry.gpu : "").trim();
    if (!v || v === "-" || v === "-%") {
      return "";
    }
    return v.indexOf("%") >= 0 ? v : v + "%";
  }

  function applyStatsPayload(data) {
    if (!data || typeof data !== "object") {
      return;
    }
    var cpuBlock = data.cpu_usages && data.cpu_usages["frigate.full_system"] ? data.cpu_usages["frigate.full_system"] : null;
    if (cpuBlock && cpuBlock.cpu !== undefined && cpuBlock.cpu !== null) {
      var c = String(cpuBlock.cpu).trim();
      root.statsCpuDisplay = c.indexOf("%") >= 0 ? c : c + "%";
    } else {
      root.statsCpuDisplay = "—";
    }
    var gpus = data.gpu_usages;
    if (!gpus || typeof gpus !== "object") {
      root.statsGpuDisplay = pluginApi?.tr("panel.stats.noGpu") ?? "—";
      return;
    }
    var keys = Object.keys(gpus);
    var parts = [];
    for (var i = 0; i < keys.length; i++) {
      var k = keys[i];
      if (k === "error-gpu" || k === "rpi-v4l2m2m") {
        continue;
      }
      var gStr = statsGpuUsageString(gpus[k]);
      if (!gStr.length) {
        continue;
      }
      var label = k;
      if (label.length > 14) {
        label = label.slice(0, 12) + "…";
      }
      parts.push(label + " " + gStr);
    }
    root.statsGpuDisplay = parts.length ? parts.join(" · ") : (pluginApi?.tr("panel.stats.noGpu") ?? "—");
  }

  function refreshFrigateStats() {
    if (!frigateBaseUrl) {
      root.statsCpuDisplay = "—";
      root.statsGpuDisplay = "—";
      return;
    }
    fetchJson("/api/stats", function (err, data) {
      if (err || !data) {
        return;
      }
      applyStatsPayload(data);
    });
  }

  function fetchJson(path, done) {
    var xhr = new XMLHttpRequest();
    xhr.open("GET", frigateBaseUrl + path);
    if (authToken.length > 0) {
      xhr.setRequestHeader("Authorization", "Bearer " + authToken);
    }
    xhr.onreadystatechange = function () {
      if (xhr.readyState === XMLHttpRequest.DONE) {
        if (xhr.status >= 200 && xhr.status < 300) {
          try {
            done(null, JSON.parse(xhr.responseText));
          } catch (e) {
            done("parse", null);
          }
        } else {
          done("http " + xhr.status, null);
        }
      }
    };
    xhr.send();
  }

  function hiddenCameraNameSet() {
    if (!root.cameraBlacklistEnabled) {
      return {};
    }
    var raw = cfg.hiddenCameras ?? defaults.hiddenCameras ?? [];
    var set = {};
    var add = function (n) {
      n = String(n).trim();
      if (n.length > 0) {
        set[n.toLowerCase()] = true;
      }
    };
    if (raw && typeof raw.length === "number" && typeof raw !== "string") {
      for (var i = 0; i < raw.length; i++) {
        add(raw[i]);
      }
    } else if (typeof raw === "string") {
      var parts = raw.split(/[,\n]/);
      for (var j = 0; j < parts.length; j++) {
        add(parts[j]);
      }
    }
    return set;
  }

  function appendCameraNamesFromKeys(keys) {
    var hidden = hiddenCameraNameSet();
    var visible = [];
    for (var k = 0; k < keys.length; k++) {
      var name = keys[k];
      if (!hidden[String(name).toLowerCase()]) {
        visible.push(name);
      }
    }
    visible.sort();
    for (var i = 0; i < visible.length; i++) {
      camerasModel.append({
        "camName": visible[i]
      });
    }
    if (keys.length === 0) {
      root.loadError = pluginApi?.tr("panel.empty") ?? "No cameras found.";
    } else if (visible.length === 0) {
      root.loadError = pluginApi?.tr("panel.allHiddenByBlacklist") ?? "All cameras are hidden by your blacklist.";
    }
  }

  function reloadCameras() {
    root.loadError = "";
    camerasModel.clear();
    if (!frigateBaseUrl) {
      root.loadError = pluginApi?.tr("panel.error.noUrl") ?? "Set Frigate URL in settings.";
      return;
    }

    // Frigate 0.16+ (FastAPI): camera list lives under GET /api/config → cameras.
    // Legacy: GET /api/cameras returned a map of camera name → status.
    // Fallback: GET /api/stats often includes a cameras object.
    fetchJson("/api/config", function (err, data) {
      if (!err && data && data.cameras && typeof data.cameras === "object") {
        appendCameraNamesFromKeys(Object.keys(data.cameras));
        return;
      }
      fetchJson("/api/cameras", function (err2, data2) {
        if (!err2 && data2 && typeof data2 === "object") {
          appendCameraNamesFromKeys(Object.keys(data2));
          return;
        }
        fetchJson("/api/stats", function (err3, data3) {
          if (!err3 && data3 && data3.cameras && typeof data3.cameras === "object") {
            appendCameraNamesFromKeys(Object.keys(data3.cameras));
            return;
          }
          var detail = err || err2 || err3 || "unknown";
          root.loadError = (pluginApi?.tr("panel.error.fetch") ?? "Could not load cameras.") + " (" + detail + ")";
          ToastService.showError(root.loadError);
        });
      });
    });
  }

  function onMjpegTileFailed() {
    if (!root.mjpegFallbackNotified) {
      root.mjpegFallbackNotified = true;
      ToastService.showNotice(pluginApi?.tr("panel.mjpeg.fallback") ?? "MJPEG failed; using snapshots for this session.");
    }
  }

  Component.onCompleted: {
    reloadCameras();
  }

  Timer {
    interval: 3000
    running: root.frigateBaseUrl.length > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refreshFrigateStats()
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      RowLayout {
        id: panelHeaderRow
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.title") ?? "Frigate cameras"
          pointSize: Style.fontSizeL
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.fillWidth: true
        }

        NIconButton {
          icon: "external-link"
          baseSize: Style.baseWidgetSize * 0.85
          tooltipText: pluginApi?.tr("panel.dashboard.tooltip") ?? "Open Frigate in browser"
          onClicked: root.openFrigateDashboard()
        }

        NIconButton {
          icon: "refresh"
          baseSize: Style.baseWidgetSize * 0.85
          onClicked: {
            root.mjpegFallbackNotified = false;
            reloadCameras();
          }
        }

        NIconButton {
          icon: "x"
          baseSize: Style.baseWidgetSize * 0.85
          onClicked: {
            if (pluginApi) {
              pluginApi.closePanel(pluginApi.panelOpenScreen);
            }
          }
        }
      }

      NText {
        id: panelErrorText
        visible: loadError.length > 0 && camerasModel.count === 0
        Layout.fillWidth: true
        text: loadError
        wrapMode: Text.WordWrap
        pointSize: Style.fontSizeM
        color: Color.mOnSurfaceVariant
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: false
        Layout.preferredHeight: root.panelScrollHeight
        visible: camerasModel.count > 0

        NScrollView {
          id: scrollView
          anchors.fill: parent
          horizontalPolicy: ScrollBar.AlwaysOff
          verticalPolicy: ScrollBar.AsNeeded

          GridLayout {
            id: cameraGrid
            width: scrollView.availableWidth
            columns: root.gridColumns
            columnSpacing: Style.marginM
            rowSpacing: Style.marginM

            Repeater {
              model: camerasModel

              delegate: Rectangle {
                id: tile
                required property string camName

                Layout.fillWidth: true
                Layout.preferredHeight: root.panelTileHeight

                radius: Style.radiusM
                color: Color.mSurfaceVariant
                border.color: Style.capsuleBorderColor
                border.width: Style.capsuleBorderWidth

                property bool mjpegFailed: false
                readonly property bool showSnapshot: !root.mjpegAllowed || mjpegFailed || root.authToken.length > 0
                property int snapshotBust: 0

                MouseArea {
                  id: tileOpenExpanded
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  z: 10
                  onClicked: root.openExpandedCam(tile.camName)
                }

                ColumnLayout {
                  anchors.fill: parent
                  anchors.margins: Style.marginS
                  spacing: Style.marginS

                  NText {
                    text: tile.camName
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                    pointSize: Style.fontSizeS
                    font.weight: Font.Medium
                    color: Color.mOnSurface
                  }

                  Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    MediaPlayer {
                      id: mjpegPlayer
                      source: root.mjpegAllowed && !tile.mjpegFailed ? (root.frigateBaseUrl + "/api/" + encodeURIComponent(tile.camName) + "?h=480&fps=10") : ""
                      videoOutput: mjpegVideo
                      onSourceChanged: {
                        if (source && source.toString().length > 0) {
                          play();
                        } else {
                          stop();
                        }
                      }
                      onErrorOccurred: function (_error, _s) {
                        tile.mjpegFailed = true;
                        stop();
                        root.onMjpegTileFailed();
                      }
                    }

                    VideoOutput {
                      id: mjpegVideo
                      anchors.fill: parent
                      visible: !tile.showSnapshot
                    }

                    Image {
                      id: snapshotImage
                      anchors.fill: parent
                      fillMode: Image.PreserveAspectFit
                      asynchronous: true
                      cache: false
                      visible: tile.showSnapshot
                      property string directSource: root.frigateBaseUrl + "/api/" + encodeURIComponent(tile.camName) + "/latest.jpg?t=" + tile.snapshotBust

                      source: root.authToken.length > 0 ? "" : directSource

                      onStatusChanged: {
                        if (status === Image.Error && root.authToken.length === 0) {
                          Logger.w("noctalia-frigate", "Snapshot load error for camera", tile.camName);
                        }
                      }
                    }

                    Timer {
                      interval: root.snapshotIntervalMs
                      running: tile.showSnapshot && root.authToken.length === 0 && camerasModel.count > 0
                      repeat: true
                      triggeredOnStart: true
                      onTriggered: {
                        tile.snapshotBust++;
                      }
                    }

                    Timer {
                      interval: root.snapshotIntervalMs
                      running: tile.showSnapshot && root.authToken.length > 0 && camerasModel.count > 0
                      repeat: true
                      triggeredOnStart: true
                      onTriggered: {
                        var xhr = new XMLHttpRequest();
                        xhr.open("GET", root.frigateBaseUrl + "/api/" + encodeURIComponent(tile.camName) + "/latest.jpg");
                        xhr.setRequestHeader("Authorization", "Bearer " + root.authToken);
                        xhr.responseType = "arraybuffer";
                        xhr.onreadystatechange = function () {
                          if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200 && xhr.response) {
                            snapshotImage.source = "data:image/jpeg;base64," + root.bytesToBase64(xhr.response);
                          }
                        };
                        xhr.send();
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      RowLayout {
        id: panelStatsRow
        Layout.fillWidth: true
        spacing: Style.marginM
        visible: root.frigateBaseUrl.length > 0

        NText {
          text: (pluginApi?.tr("panel.stats.cpu") ?? "CPU") + " " + root.statsCpuDisplay
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
        }

        NText {
          text: (pluginApi?.tr("panel.stats.gpu") ?? "GPU") + " " + root.statsGpuDisplay
          Layout.fillWidth: true
          pointSize: Style.fontSizeS
          color: Color.mOnSurfaceVariant
          elide: Text.ElideRight
        }
      }
    }

    Item {
      id: expandLayer
      anchors.fill: parent
      visible: root.expandedCameraName.length > 0
      z: 2000

      // Invisible hit target only — a translucent dimmer Rectangle composites badly on some
      // setups (black bands / fringes). Clicks outside the card still close the overlay.
      MouseArea {
        anchors.fill: parent
        z: 0
        cursorShape: Qt.PointingHandCursor
        onClicked: root.closeExpanded()
      }

      Rectangle {
        id: expandCard
        anchors.centerIn: parent
        width: Math.min(panelContainer.width - Style.marginL * 2, 960 * Style.uiScaleRatio)
        height: Math.min(panelContainer.height - Style.marginL * 2, 680 * Style.uiScaleRatio)
        z: 1
        radius: Style.radiusL
        color: Color.mSurface
        border.color: Style.capsuleBorderColor
        border.width: Style.capsuleBorderWidth
        clip: true

        ColumnLayout {
          id: expandCardLayout
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NText {
              text: root.expandedCameraName
              Layout.fillWidth: true
              elide: Text.ElideMiddle
              pointSize: Style.fontSizeL
              font.weight: Font.Bold
              color: Color.mOnSurface
            }

            NIconButton {
              icon: "x"
              baseSize: Style.baseWidgetSize
              onClicked: root.closeExpanded()
            }
          }

          Item {
            id: expandStreamViewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            onWidthChanged: root.clampExpandPan()
            onHeightChanged: root.clampExpandPan()

            Item {
              id: expandStreamScaled
              width: expandStreamViewport.width
              height: expandStreamViewport.height
              x: root.expandedPanX
              y: root.expandedPanY
              scale: root.expandedZoom
              transformOrigin: Item.TopLeft

              MediaPlayer {
                id: expandedMjpegPlayer
                source: root.expandedCameraName.length > 0 && root.mjpegAllowed && !root.expandedMjpegFailed ? (root.frigateBaseUrl + "/api/" + encodeURIComponent(root.expandedCameraName) + "?h=720&fps=24") : ""
                videoOutput: expandedMjpegVideo
                onSourceChanged: {
                  if (source && source.toString().length > 0) {
                    play();
                  } else {
                    stop();
                  }
                }
                onErrorOccurred: function (_e, _s) {
                  root.expandedMjpegFailed = true;
                  stop();
                  ToastService.showNotice(pluginApi?.tr("panel.expand.mjpegFallback") ?? "Using snapshots for enlarged view.");
                }
              }

              VideoOutput {
                id: expandedMjpegVideo
                anchors.fill: parent
                visible: root.expandedCameraName.length > 0 && !root.expandedShowSnapshot
              }

              Image {
                id: expandedSnapshotImage
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
                visible: root.expandedCameraName.length > 0 && root.expandedShowSnapshot
                property string expandedDirectSource: root.frigateBaseUrl + "/api/" + encodeURIComponent(root.expandedCameraName) + "/latest.jpg?t=" + root.expandedSnapshotBust

                source: root.authToken.length > 0 ? "" : expandedDirectSource
              }
            }

            MouseArea {
              id: expandZoomMouse
              anchors.fill: parent
              hoverEnabled: true
              acceptedButtons: Qt.LeftButton
              cursorShape: root.expandedZoom > root.expandedZoomMin + 0.02 ? (expandZoomMouse.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor) : Qt.ArrowCursor

              property real dragStartX: 0
              property real dragStartY: 0
              property real panStartX: 0
              property real panStartY: 0

              onPressed: function (mouse) {
                dragStartX = mouse.x;
                dragStartY = mouse.y;
                panStartX = root.expandedPanX;
                panStartY = root.expandedPanY;
              }

              onPositionChanged: function (mouse) {
                if (!expandZoomMouse.pressed || root.expandedZoom <= root.expandedZoomMin + 0.02) {
                  return;
                }
                root.expandedPanX = panStartX + (mouse.x - dragStartX);
                root.expandedPanY = panStartY + (mouse.y - dragStartY);
                root.clampExpandPan();
              }

              onWheel: function (wheel) {
                var dy = wheel.angleDelta.y;
                if (dy === 0) {
                  dy = wheel.angleDelta.x;
                }
                if (dy === 0) {
                  return;
                }
                var steps = Math.abs(dy) / 120;
                if (steps < 1) {
                  steps = 1;
                }
                var factor = dy > 0 ? Math.pow(1.12, steps) : Math.pow(1 / 1.12, steps);
                root.applyExpandZoomAt(wheel.x, wheel.y, factor);
                wheel.accepted = true;
              }

              onDoubleClicked: function (mouse) {
                mouse.accepted = true;
                root.resetExpandViewTransform();
              }
            }

            Timer {
              id: expandedSnapTimerOpen
              interval: root.snapshotIntervalMs
              running: root.expandedCameraName.length > 0 && root.expandedShowSnapshot && root.authToken.length === 0
              repeat: true
              triggeredOnStart: true
              onTriggered: root.expandedSnapshotBust++
            }

            Timer {
              id: expandedSnapTimerAuth
              interval: root.snapshotIntervalMs
              running: root.expandedCameraName.length > 0 && root.expandedShowSnapshot && root.authToken.length > 0
              repeat: true
              triggeredOnStart: true
              onTriggered: {
                if (root.expandedCameraName.length === 0) {
                  return;
                }
                var xhr = new XMLHttpRequest();
                xhr.open("GET", root.frigateBaseUrl + "/api/" + encodeURIComponent(root.expandedCameraName) + "/latest.jpg");
                xhr.setRequestHeader("Authorization", "Bearer " + root.authToken);
                xhr.responseType = "arraybuffer";
                xhr.onreadystatechange = function () {
                  if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200 && xhr.response) {
                    expandedSnapshotImage.source = "data:image/jpeg;base64," + root.bytesToBase64(xhr.response);
                  }
                };
                xhr.send();
              }
            }
          }
        }
      }
    }
  }
}
