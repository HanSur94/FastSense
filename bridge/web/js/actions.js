/* ============================================================
   actions.js — Action panel: render buttons and POST on click
   ============================================================ */

var Actions = (function () {
    "use strict";

    var panelEl = null;

    function getPanel() {
        if (!panelEl) panelEl = document.getElementById("action-panel");
        return panelEl;
    }

    /* --- public API ---------------------------------------- */
    function render(actionNames) {
        var panel = getPanel();
        panel.innerHTML = "";

        if (!actionNames || actionNames.length === 0) {
            panel.classList.remove("open");
            return;
        }

        panel.classList.add("open");

        var heading = document.createElement("h2");
        heading.textContent = "Actions";
        panel.appendChild(heading);

        for (var i = 0; i < actionNames.length; i++) {
            var btn = createButton(actionNames[i]);
            panel.appendChild(btn);
        }
    }

    function createButton(name) {
        var btn = document.createElement("button");
        btn.className = "action-btn";
        btn.textContent = name;
        btn.addEventListener("click", function () {
            invoke(name, btn);
        });
        return btn;
    }

    function invoke(name, btn) {
        btn.classList.add("loading");

        fetch("/api/actions/" + encodeURIComponent(name), {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ args: {} })
        })
        .then(function (r) {
            if (!r.ok) throw new Error("HTTP " + r.status);
            return r.json();
        })
        .then(function () {
            showToast("Action '" + name + "' completed", "success");
        })
        .catch(function (err) {
            showToast("Action '" + name + "' failed: " + err.message, "error");
        })
        .finally(function () {
            btn.classList.remove("loading");
        });
    }

    return { render: render };
})();
