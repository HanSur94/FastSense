/* ============================================================
   dashboard.js — Layout renderer for dashboard grid
   ============================================================ */

var Dashboard = (function () {
    "use strict";

    var gridEl = null;

    function getGrid() {
        if (!gridEl) gridEl = document.getElementById("dashboard-grid");
        return gridEl;
    }

    /* --- public API ---------------------------------------- */
    function render(config) {
        Chart.destroyAll();

        var grid = getGrid();
        grid.innerHTML = "";

        if (config.name || config.title) {
            var titleEl = document.getElementById("dashboard-title");
            if (titleEl) titleEl.textContent = config.name || config.title;
        }

        var widgets = config.widgets || [];
        for (var i = 0; i < widgets.length; i++) {
            var w = widgets[i];
            var card = createCard(w);
            grid.appendChild(card);
        }
    }

    /* --- card factory -------------------------------------- */
    function createCard(widgetCfg) {
        var card = document.createElement("div");
        card.className = "widget";
        card.dataset.widgetId = widgetCfg.id || "";

        // Grid placement from position: { col, row, width, height }
        var pos = widgetCfg.position || {};
        if (pos.col != null && pos.width != null) {
            card.style.gridColumn = pos.col + " / span " + pos.width;
        }
        if (pos.row != null && pos.height != null) {
            card.style.gridRow = pos.row + " / span " + pos.height;
        }

        // Header
        if (widgetCfg.title) {
            var header = document.createElement("div");
            header.className = "widget-header";
            header.textContent = widgetCfg.title;
            card.appendChild(header);
        }

        // Body
        var body = document.createElement("div");
        body.className = "widget-body";
        card.appendChild(body);

        // Render widget content
        Widgets.render(widgetCfg, body);

        return card;
    }

    return { render: render };
})();
