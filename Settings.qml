import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets
import qs.Services.UI

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueFrigateBaseUrl: cfg.frigateBaseUrl ?? defaults.frigateBaseUrl ?? ""
  property bool valueUseMjpeg: cfg.useMjpeg ?? defaults.useMjpeg ?? false
  property string valueSnapshotIntervalMs: String(cfg.snapshotIntervalMs ?? defaults.snapshotIntervalMs ?? 750)
  property string valueHttpAuthToken: cfg.httpAuthToken ?? defaults.httpAuthToken ?? ""
  property string valueGridColumns: String(cfg.gridColumns ?? defaults.gridColumns ?? 2)
  property bool valueCameraBlacklistEnabled: cfg.cameraBlacklistEnabled ?? defaults.cameraBlacklistEnabled ?? true
  property string valueHiddenCamerasText: hiddenCamerasToText(cfg.hiddenCameras ?? defaults.hiddenCameras)

  spacing: Style.marginL

  function hiddenCamerasToText(raw) {
    if (!raw) {
      return "";
    }
    if (typeof raw === "string") {
      return raw;
    }
    if (typeof raw.length === "number") {
      var out = [];
      for (var i = 0; i < raw.length; i++) {
        var s = String(raw[i]).trim();
        if (s.length > 0) {
          out.push(s);
        }
      }
      return out.join(", ");
    }
    return "";
  }

  Component.onCompleted: {
    Logger.i("noctalia-frigate", "Settings UI loaded");
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.baseUrl.label")
      description: pluginApi?.tr("settings.baseUrl.desc")
      placeholderText: "http://127.0.0.1:5000"
      text: root.valueFrigateBaseUrl
      onTextChanged: root.valueFrigateBaseUrl = text
    }

    NToggle {
      label: pluginApi?.tr("settings.useMjpeg.label")
      description: pluginApi?.tr("settings.useMjpeg.desc")
      checked: root.valueUseMjpeg
      onToggled: checked => {
        root.valueUseMjpeg = checked;
      }
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.snapshotInterval.label")
      description: pluginApi?.tr("settings.snapshotInterval.desc")
      placeholderText: "750"
      text: root.valueSnapshotIntervalMs
      onTextChanged: root.valueSnapshotIntervalMs = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.token.label")
      description: pluginApi?.tr("settings.token.desc")
      placeholderText: ""
      text: root.valueHttpAuthToken
      onTextChanged: root.valueHttpAuthToken = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.gridColumns.label")
      description: pluginApi?.tr("settings.gridColumns.desc")
      placeholderText: "2"
      text: root.valueGridColumns
      onTextChanged: root.valueGridColumns = text
    }

    NToggle {
      label: pluginApi?.tr("settings.cameraBlacklist.enabled.label")
      description: pluginApi?.tr("settings.cameraBlacklist.enabled.desc")
      checked: root.valueCameraBlacklistEnabled
      onToggled: checked => {
        root.valueCameraBlacklistEnabled = checked;
      }
    }

    NTextInput {
      Layout.fillWidth: true
      label: pluginApi?.tr("settings.cameraBlacklist.names.label")
      description: pluginApi?.tr("settings.cameraBlacklist.names.desc")
      placeholderText: "front_door, alley"
      text: root.valueHiddenCamerasText
      onTextChanged: root.valueHiddenCamerasText = text
    }
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("noctalia-frigate", "Cannot save settings: pluginApi is null");
      return;
    }

    var interval = parseInt(root.valueSnapshotIntervalMs, 10);
    if (isNaN(interval)) {
      interval = pluginApi.manifest?.metadata?.defaultSettings?.snapshotIntervalMs ?? 750;
    }
    interval = Math.max(200, interval);

    var cols = parseInt(root.valueGridColumns, 10);
    if (isNaN(cols)) {
      cols = pluginApi.manifest?.metadata?.defaultSettings?.gridColumns ?? 2;
    }
    cols = Math.max(1, Math.min(4, cols));

    var url = root.valueFrigateBaseUrl.trim();
    while (url.endsWith("/")) {
      url = url.slice(0, -1);
    }

    pluginApi.pluginSettings.frigateBaseUrl = url;
    pluginApi.pluginSettings.useMjpeg = root.valueUseMjpeg;
    pluginApi.pluginSettings.snapshotIntervalMs = interval;
    pluginApi.pluginSettings.httpAuthToken = root.valueHttpAuthToken.trim();
    pluginApi.pluginSettings.gridColumns = cols;
    pluginApi.pluginSettings.cameraBlacklistEnabled = root.valueCameraBlacklistEnabled;

    var hiddenList = [];
    var parts = root.valueHiddenCamerasText.split(/[,\n]/);
    for (var h = 0; h < parts.length; h++) {
      var part = parts[h].trim();
      if (part.length > 0) {
        hiddenList.push(part);
      }
    }
    pluginApi.pluginSettings.hiddenCameras = hiddenList;

    pluginApi.saveSettings();
    ToastService.showNotice(pluginApi?.tr("settings.saved") ?? "Settings saved.");
    Logger.i("noctalia-frigate", "Settings saved");
  }
}
