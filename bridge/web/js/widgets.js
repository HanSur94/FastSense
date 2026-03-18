/* ============================================================
   widgets.js — Widget renderers for each dashboard tile type
   ============================================================ */

var Widgets = (function () {
    "use strict";

    /* --- public dispatch ----------------------------------- */
    function render(config, bodyEl) {
        var type = config.type || "text";
        switch (type) {
            case "fastsense": return renderFastSense(config, bodyEl);
            case "kpi":      return renderKPI(config, bodyEl);
            case "status":   return renderStatus(config, bodyEl);
            case "table":    return renderTable(config, bodyEl);
            case "gauge":    return renderGauge(config, bodyEl);
            case "text":     return renderText(config, bodyEl);
            case "timeline": return renderTimeline(config, bodyEl);
            case "rawaxes":  return renderRawAxes(config, bodyEl);
            case "group":    return renderGroup(config, bodyEl);
            case "heatmap":  return renderHeatmap(config, bodyEl);
            case "barchart": return renderBarChart(config, bodyEl);
            case "histogram":return renderHistogram(config, bodyEl);
            case "scatter":  return renderScatter(config, bodyEl);
            case "image":    return renderImage(config, bodyEl);
            case "multistatus": return renderMultiStatus(config, bodyEl);
            default:
                bodyEl.textContent = "Unknown widget type: " + type;
        }
    }

    /* --- fastsense (uPlot chart) ---------------------------- */
    function renderFastSense(cfg, el) {
        el.classList.add("chart-body");
        var signalId = cfg.signalId || cfg.id;
        Chart.create(signalId, el);
    }

    /* --- KPI ----------------------------------------------- */
    function renderKPI(cfg, el) {
        var valDiv = document.createElement("div");
        valDiv.className = "kpi-value";

        var formatted = formatNumber(cfg.value);
        valDiv.textContent = formatted;

        if (cfg.unit) {
            var unitSpan = document.createElement("span");
            unitSpan.className = "kpi-unit";
            unitSpan.textContent = cfg.unit;
            valDiv.appendChild(unitSpan);
        }
        el.appendChild(valDiv);

        if (cfg.trend != null) {
            var trendDiv = document.createElement("div");
            var dir = cfg.trend > 0 ? "up" : cfg.trend < 0 ? "down" : "flat";
            trendDiv.className = "kpi-trend " + dir;
            var arrow = dir === "up" ? "\u25B2" : dir === "down" ? "\u25BC" : "\u25CF";
            trendDiv.textContent = arrow + " " + Math.abs(cfg.trend);
            if (cfg.trendUnit) trendDiv.textContent += " " + cfg.trendUnit;
            el.appendChild(trendDiv);
        }
    }

    /* --- Status -------------------------------------------- */
    function renderStatus(cfg, el) {
        el.style.display = "flex";
        el.style.alignItems = "center";
        el.style.justifyContent = "center";

        var level = (cfg.level || cfg.status || "ok").toLowerCase();
        var cls = "status-badge status-" + level;

        var badge = document.createElement("div");
        badge.className = cls;

        var dot = document.createElement("span");
        dot.className = "status-dot";
        badge.appendChild(dot);

        var label = document.createElement("span");
        label.textContent = cfg.label || level;
        badge.appendChild(label);

        el.appendChild(badge);
    }

    /* --- Table --------------------------------------------- */
    function renderTable(cfg, el) {
        var table = document.createElement("table");
        table.className = "widget-table";

        if (cfg.headers && cfg.headers.length) {
            var thead = document.createElement("thead");
            var tr = document.createElement("tr");
            for (var h = 0; h < cfg.headers.length; h++) {
                var th = document.createElement("th");
                th.textContent = cfg.headers[h];
                tr.appendChild(th);
            }
            thead.appendChild(tr);
            table.appendChild(thead);
        }

        if (cfg.rows && cfg.rows.length) {
            var tbody = document.createElement("tbody");
            for (var r = 0; r < cfg.rows.length; r++) {
                var row = document.createElement("tr");
                var cells = cfg.rows[r];
                for (var c = 0; c < cells.length; c++) {
                    var td = document.createElement("td");
                    td.textContent = cells[c];
                    row.appendChild(td);
                }
                tbody.appendChild(row);
            }
            table.appendChild(tbody);
        }

        el.appendChild(table);
    }

    /* --- Gauge --------------------------------------------- */
    function renderGauge(cfg, el) {
        el.classList.add("gauge-container");

        var value = cfg.value != null ? cfg.value : 0;
        var min   = cfg.min   != null ? cfg.min   : 0;
        var max   = cfg.max   != null ? cfg.max   : 100;
        var pct   = Math.max(0, Math.min(1, (value - min) / (max - min)));

        var startAngle = -225;
        var endAngle   =  45;
        var sweep      = endAngle - startAngle; // 270 degrees
        var needleAngle = startAngle + pct * sweep;

        var cx = 100, cy = 100, r = 80;
        var svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
        svg.setAttribute("viewBox", "0 0 200 160");
        svg.setAttribute("width", "200");
        svg.setAttribute("height", "160");

        // background arc
        svg.innerHTML = arcPath(cx, cy, r, startAngle, endAngle, "#2a2d3a", 10)
                       + arcPath(cx, cy, r, startAngle, startAngle + pct * sweep, gaugeColor(pct), 10)
                       + needlePath(cx, cy, r - 10, needleAngle);

        el.appendChild(svg);

        var labelDiv = document.createElement("div");
        labelDiv.className = "gauge-label";
        labelDiv.textContent = formatNumber(value);
        if (cfg.unit) labelDiv.textContent += " " + cfg.unit;
        el.appendChild(labelDiv);
    }

    function gaugeColor(pct) {
        if (pct < 0.5) return "#34d399";
        if (pct < 0.8) return "#fbbf24";
        return "#f87171";
    }

    function polarToXY(cx, cy, r, deg) {
        var rad = (deg * Math.PI) / 180;
        return { x: cx + r * Math.cos(rad), y: cy + r * Math.sin(rad) };
    }

    function arcPath(cx, cy, r, startDeg, endDeg, color, width) {
        var s = polarToXY(cx, cy, r, startDeg);
        var e = polarToXY(cx, cy, r, endDeg);
        var largeArc = Math.abs(endDeg - startDeg) > 180 ? 1 : 0;
        return '<path d="M' + s.x + ',' + s.y +
               ' A' + r + ',' + r + ' 0 ' + largeArc + ' 1 ' + e.x + ',' + e.y + '"' +
               ' fill="none" stroke="' + color + '" stroke-width="' + width + '"' +
               ' stroke-linecap="round"/>';
    }

    function needlePath(cx, cy, len, deg) {
        var tip = polarToXY(cx, cy, len, deg);
        return '<line x1="' + cx + '" y1="' + cy + '" x2="' + tip.x + '" y2="' + tip.y + '"' +
               ' stroke="#e4e6ef" stroke-width="2.5" stroke-linecap="round"/>' +
               '<circle cx="' + cx + '" cy="' + cy + '" r="5" fill="#e4e6ef"/>';
    }

    /* --- Text ---------------------------------------------- */
    function renderText(cfg, el) {
        el.classList.add("text-widget-body");
        el.textContent = cfg.text || cfg.content || "";
    }

    /* --- Timeline ------------------------------------------ */
    function renderTimeline(cfg, el) {
        var container = document.createElement("div");
        container.className = "timeline-container";

        var events = cfg.events || [];
        var tMin = cfg.tMin != null ? cfg.tMin : 0;
        var tMax = cfg.tMax != null ? cfg.tMax : 1;
        var range = tMax - tMin || 1;

        for (var i = 0; i < events.length; i++) {
            var ev = events[i];
            var row = document.createElement("div");
            row.className = "timeline-row";

            var label = document.createElement("span");
            label.className = "timeline-label";
            label.textContent = ev.label || "";
            row.appendChild(label);

            var track = document.createElement("div");
            track.className = "timeline-track";

            var bar = document.createElement("div");
            bar.className = "timeline-bar";
            var left  = ((ev.start - tMin) / range) * 100;
            var width = (((ev.end || ev.start) - ev.start) / range) * 100;
            bar.style.left  = Math.max(0, left) + "%";
            bar.style.width = Math.max(0.5, width) + "%";
            bar.style.background = ev.color || "#4e8cff";
            track.appendChild(bar);

            row.appendChild(track);
            container.appendChild(row);
        }

        el.appendChild(container);
    }

    /* --- RawAxes placeholder ------------------------------- */
    function renderRawAxes(cfg, el) {
        el.innerHTML = '<div class="rawaxes-placeholder">' +
            '<div class="icon">\u2328</div>' +
            '<div class="label">View in MATLAB</div>' +
            '</div>';
    }

    /* --- Group --------------------------------------------- */
    function renderGroup(config, container) {
        var mode = config.mode || 'panel';
        var label = config.label || '';

        // Header
        if (label) {
            var header = document.createElement('div');
            header.className = 'widget-group-header';
            header.textContent = label;

            if (mode === 'collapsible') {
                var toggle = document.createElement('span');
                toggle.className = 'widget-group-toggle';
                toggle.textContent = config.collapsed ? '>' : 'v';
                header.insertBefore(toggle, header.firstChild);
                header.style.cursor = 'pointer';
                header.addEventListener('click', function() {
                    var content = container.querySelector('.widget-group-content');
                    var isCollapsed = content.style.display === 'none';
                    content.style.display = isCollapsed ? 'grid' : 'none';
                    toggle.textContent = isCollapsed ? 'v' : '>';
                });
            }

            if (mode === 'tabbed' && config.tabs && config.tabs.length > 0) {
                var tabBar = document.createElement('div');
                tabBar.className = 'widget-group-tabbar';
                config.tabs.forEach(function(tab, idx) {
                    var tabBtn = document.createElement('button');
                    tabBtn.className = 'widget-group-tab';
                    if (tab.name === config.activeTab) {
                        tabBtn.classList.add('active');
                    }
                    tabBtn.textContent = tab.name;
                    tabBtn.addEventListener('click', function() {
                        var panels = container.querySelectorAll('.widget-group-tabpanel');
                        panels.forEach(function(p) { p.style.display = 'none'; });
                        panels[idx].style.display = 'grid';
                        tabBar.querySelectorAll('.widget-group-tab').forEach(function(b) {
                            b.classList.remove('active');
                        });
                        tabBtn.classList.add('active');
                    });
                    tabBar.appendChild(tabBtn);
                });
                header.appendChild(tabBar);
            }

            container.appendChild(header);
        }

        // Content
        if (mode === 'tabbed' && config.tabs) {
            config.tabs.forEach(function(tab, idx) {
                var tabPanel = document.createElement('div');
                tabPanel.className = 'widget-group-tabpanel widget-group-content';
                tabPanel.style.display = (tab.name === config.activeTab) ? 'grid' : 'none';
                tabPanel.style.gridTemplateColumns = 'repeat(auto-fit, minmax(200px, 1fr))';
                tabPanel.style.gap = '8px';
                tabPanel.style.padding = '8px';

                (tab.widgets || []).forEach(function(wCfg) {
                    var wEl = document.createElement('div');
                    wEl.className = 'widget';
                    var wBody = document.createElement('div');
                    wBody.className = 'widget-body';
                    wEl.appendChild(wBody);
                    render(wCfg, wBody);
                    tabPanel.appendChild(wEl);
                });
                container.appendChild(tabPanel);
            });
        } else {
            var content = document.createElement('div');
            content.className = 'widget-group-content';
            content.style.display = config.collapsed ? 'none' : 'grid';
            content.style.gridTemplateColumns = 'repeat(auto-fit, minmax(200px, 1fr))';
            content.style.gap = '8px';
            content.style.padding = '8px';

            (config.children || []).forEach(function(childCfg) {
                var wEl = document.createElement('div');
                wEl.className = 'widget';
                var wBody = document.createElement('div');
                wBody.className = 'widget-body';
                wEl.appendChild(wBody);
                render(childCfg, wBody);
                content.appendChild(wEl);
            });
            container.appendChild(content);
        }

    /* --- Heatmap ------------------------------------------- */
    function renderHeatmap(cfg, el) {
        el.innerHTML = '<div class="placeholder-widget">' +
            '<div class="icon">&#x1F7E5;</div>' +
            '<div class="label">Heatmap: ' + (cfg.title || '') + '</div>' +
            '</div>';
    }

    /* --- Bar Chart ----------------------------------------- */
    function renderBarChart(cfg, el) {
        el.innerHTML = '<div class="placeholder-widget">' +
            '<div class="icon">&#x1F4CA;</div>' +
            '<div class="label">Bar Chart: ' + (cfg.title || '') + '</div>' +
            '</div>';
    }

    /* --- Histogram ----------------------------------------- */
    function renderHistogram(cfg, el) {
        el.innerHTML = '<div class="placeholder-widget">' +
            '<div class="icon">&#x1F4C8;</div>' +
            '<div class="label">Histogram: ' + (cfg.title || '') + '</div>' +
            '</div>';
    }

    /* --- Scatter ------------------------------------------- */
    function renderScatter(cfg, el) {
        el.innerHTML = '<div class="placeholder-widget">' +
            '<div class="icon">&#x2022;</div>' +
            '<div class="label">Scatter: ' + (cfg.title || '') + '</div>' +
            '</div>';
    }

    /* --- Image --------------------------------------------- */
    function renderImage(cfg, el) {
        if (cfg.file) {
            var img = document.createElement("img");
            img.src = cfg.file;
            img.alt = cfg.title || "Image";
            img.style.maxWidth = "100%";
            img.style.maxHeight = "100%";
            img.style.objectFit = "contain";
            el.appendChild(img);
        } else {
            el.innerHTML = '<div class="placeholder-widget">' +
                '<div class="icon">&#x1F5BC;</div>' +
                '<div class="label">Image: ' + (cfg.title || '') + '</div>' +
                '</div>';
        }
    }

    /* --- Multi-Status -------------------------------------- */
    function renderMultiStatus(cfg, el) {
        var items = cfg.items || [];
        if (items.length === 0) {
            el.innerHTML = '<div class="placeholder-widget">' +
                '<div class="label">Multi-Status: ' + (cfg.title || '') + '</div>' +
                '</div>';
            return;
        }
        var grid = document.createElement("div");
        grid.style.display = "grid";
        grid.style.gridTemplateColumns = "repeat(auto-fill, minmax(80px, 1fr))";
        grid.style.gap = "6px";
        grid.style.padding = "8px";
        for (var i = 0; i < items.length; i++) {
            var item = items[i];
            var cell = document.createElement("div");
            cell.style.display = "flex";
            cell.style.alignItems = "center";
            cell.style.gap = "4px";
            var dot = document.createElement("span");
            dot.style.width = "10px";
            dot.style.height = "10px";
            dot.style.borderRadius = "50%";
            dot.style.display = "inline-block";
            dot.style.backgroundColor = item.color || "#888";
            cell.appendChild(dot);
            var lbl = document.createElement("span");
            lbl.style.fontSize = "0.8em";
            lbl.textContent = item.label || "";
            cell.appendChild(lbl);
            grid.appendChild(cell);
        }
        el.appendChild(grid);
    }

    /* --- helpers ------------------------------------------- */
    function formatNumber(v) {
        if (v == null) return "--";
        if (typeof v !== "number") return String(v);
        if (Math.abs(v) >= 1e6)  return (v / 1e6).toFixed(1) + "M";
        if (Math.abs(v) >= 1e3)  return (v / 1e3).toFixed(1) + "k";
        if (Number.isInteger(v)) return v.toString();
        return v.toFixed(2);
    }

    return { render: render, renderGroup: renderGroup };
})();
