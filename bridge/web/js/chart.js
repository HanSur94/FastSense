/* ============================================================
   chart.js — uPlot wrapper for FastPlot time-series signals
   ============================================================ */

var Chart = (function () {
    "use strict";

    var MAX_POINTS = 4000;
    var instances = {};  // signalId → { plot, observer, container }

    /* --- helpers -------------------------------------------- */
    function fetchJSON(url) {
        return fetch(url).then(function (r) {
            if (!r.ok) throw new Error("HTTP " + r.status);
            return r.json();
        });
    }

    function buildOpts(container, seriesLabels) {
        var series = [{}]; // x-axis placeholder
        for (var i = 0; i < seriesLabels.length; i++) {
            series.push({
                label: seriesLabels[i],
                stroke: seriesColor(i),
                width: 1.5
            });
        }

        return {
            width:  container.clientWidth,
            height: container.clientHeight,
            cursor: { drag: { x: true, y: false } },
            scales: { x: { time: true } },
            series: series,
            hooks: {
                setScale: [onZoom]
            }
        };
    }

    var PALETTE = [
        "#4e8cff", "#34d399", "#fbbf24", "#f87171",
        "#a78bfa", "#f472b6", "#38bdf8", "#fb923c"
    ];

    function seriesColor(i) {
        return PALETTE[i % PALETTE.length];
    }

    /* --- zoom / pan handler -------------------------------- */
    function onZoom(plot, scaleKey) {
        if (scaleKey !== "x") return;
        var min = plot.scales.x.min;
        var max = plot.scales.x.max;
        if (min == null || max == null) return;

        var signalId = plot._fpSignalId;
        if (!signalId) return;

        fetchData(signalId, min, max).then(function (result) {
            if (instances[signalId]) {
                instances[signalId].plot.setData(result.data);
            }
        });
    }

    /* --- data fetching ------------------------------------- */
    function fetchData(signalId, xMin, xMax) {
        var url = "/api/signals/" + encodeURIComponent(signalId) + "/data";
        var params = ["maxPoints=" + MAX_POINTS];
        if (xMin != null) params.push("xMin=" + xMin);
        if (xMax != null) params.push("xMax=" + xMax);
        url += "?" + params.join("&");

        return fetchJSON(url).then(function (resp) {
            // Server returns { x: [...], y: [...] }
            var x = resp.x || [];
            var y = resp.y || [];
            return { data: [x, y], labels: [signalId] };
        });
    }

    /* --- public API ---------------------------------------- */
    function create(signalId, container) {
        if (instances[signalId]) destroy(signalId);

        fetchData(signalId).then(function (result) {
            if (!container.parentNode) return; // detached

            var opts = buildOpts(container, result.labels);
            var plot = new uPlot(opts, result.data, container);
            plot._fpSignalId = signalId;

            var observer = new ResizeObserver(function () {
                if (container.clientWidth > 0 && container.clientHeight > 0) {
                    plot.setSize({
                        width:  container.clientWidth,
                        height: container.clientHeight
                    });
                }
            });
            observer.observe(container);

            instances[signalId] = {
                plot: plot,
                observer: observer,
                container: container
            };
        }).catch(function (err) {
            console.error("[Chart] Failed to load signal " + signalId, err);
        });
    }

    function refresh(signalId) {
        var inst = instances[signalId];
        if (!inst) return;

        var min = inst.plot.scales.x.min;
        var max = inst.plot.scales.x.max;

        fetchData(signalId, min, max).then(function (result) {
            if (instances[signalId]) {
                instances[signalId].plot.setData(result.data);
            }
        });
    }

    function destroy(signalId) {
        var inst = instances[signalId];
        if (!inst) return;
        inst.observer.disconnect();
        inst.plot.destroy();
        delete instances[signalId];
    }

    function destroyAll() {
        var ids = Object.keys(instances);
        for (var i = 0; i < ids.length; i++) {
            destroy(ids[i]);
        }
    }

    function getSignalIds() {
        return Object.keys(instances);
    }

    return {
        create:       create,
        refresh:      refresh,
        destroy:      destroy,
        destroyAll:   destroyAll,
        getSignalIds: getSignalIds
    };
})();
