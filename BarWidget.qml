import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  function frigateDashboardUrl() {
    var cfg = root.pluginApi?.pluginSettings || {};
    var def = root.pluginApi?.manifest?.metadata?.defaultSettings || {};
    var url = String(cfg.frigateBaseUrl ?? def.frigateBaseUrl ?? "").trim();
    while (url.endsWith("/")) {
      url = url.slice(0, -1);
    }
    return url;
  }

  function openFrigateDashboard() {
    var url = frigateDashboardUrl();
    if (!url.length) {
      ToastService.showError(root.pluginApi?.tr("panel.dashboard.noUrl") ?? "Set Frigate URL in settings first.");
      return;
    }
    Quickshell.execDetached(["xdg-open", url]);
  }

  icon: "device-cctv"
  tooltipText: pluginApi?.tr("bar.tooltip") ?? "Frigate cameras"
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.mOnSurface

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      pluginApi.openPanel(root.screen, this);
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.dashboard") ?? "Open Frigate dashboard",
        "action": "dashboard",
        "icon": "external-link"
      },
      {
        "label": pluginApi?.tr("menu.settings") ?? "Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "dashboard") {
        root.openFrigateDashboard();
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  onRightClicked: {
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}
