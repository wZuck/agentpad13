(() => {
  "use strict";

  const fallbackStages = [
    {
      id: "s1",
      code: "S1",
      count: "51 件",
      color: "#2563eb",
      title: "底层固定 R / C / FB",
      subtitle: "LOW PROFILE",
      image: "stage-s1.zh-CN.png",
      summary: "先焊最低矮的固定被动件，建立电源去耦、USB 终端和主控外围。",
      parts: ["C16-C17 · 10u", "100n ×30", "1u ×4", "15p ×2", "R1-R12", "FB1"],
      steps: [
        "先焊 0805 的 C16、C17，再焊全部 0402 电容。",
        "100 nF 固定 30 颗：C1-C10、C13、C20-C24、C26-C39。",
        "按值分袋焊 5.1k、27Ω、1k、10k、4.7k、0Ω，不要混值。",
        "最后焊 FB1 600Ω@100MHz；它外形像电阻，不能混进 R 袋。"
      ],
      checkpoint: "S1 是透明版固定 51 件。不要装 C25；C40-C49 留到 S5。"
    },
    {
      id: "s2",
      code: "S2",
      count: "4 件",
      color: "#0f766e",
      title: "USB / 电源入口",
      subtitle: "POWER CHECKPOINT",
      image: "stage-s2.zh-CN.png",
      summary: "先建立 USB 输入和 3.3 V，把 RP2040 留到电压验证之后再焊。",
      parts: ["U3 · AP2112K-3.3", "U4 · USBLC6-2SC6", "F1 · 750mA", "J1 · USB-C 16P"],
      steps: [
        "首先焊 U3 AP2112K-3.3 和 U4 USBLC6-2SC6，均对齐 pin 1。",
        "焊 F1 750mA 自恢复保险丝；1812 封装必须平贴。",
        "最后焊 J1 USB-C 16P：先固定两端壳脚，再逐脚焊信号。",
        "限流 100mA 上电，确认 VBUS 无短路、U3 输出约 3.3 V。"
      ],
      checkpoint: "3.3 V 异常就停止。不要继续装 U1，先查 J1、U3 方向和连锡。"
    },
    {
      id: "s3",
      code: "S3",
      count: "3 件",
      color: "#ea580c",
      title: "MCU / Flash / 晶振",
      subtitle: "FINE PITCH",
      image: "stage-s3.zh-CN.png",
      summary: "本板最难的 QFN-56 在这一步，必须使用锡膏和热风。",
      parts: ["U1 · RP2040", "U2 · W25Q128", "Y1 · 12MHz"],
      steps: [
        "U1 薄涂锡膏，中心散热焊盘少量，对齐 pin 1 后低风速热风回流。",
        "U2 W25Q128JVSIQ 对齐 pin 1，使用热风或拖焊。",
        "Y1 12MHz 四脚晶振按板图方向放正，不能歪斜。",
        "冷却后清理 U1 脚间连锡，再复查 3.3 V 和 U1 中心焊盘。"
      ],
      checkpoint: "QFN 四边不能连锡，中心焊盘不能漏焊，不能用烙铁硬推芯片。"
    },
    {
      id: "s4",
      code: "S4",
      count: "2 件",
      color: "#7c3aed",
      title: "灯控 / 触摸 IC",
      subtitle: "SOT-23-6",
      image: "stage-s4.zh-CN.png",
      summary: "补齐 LED 电平转换和触摸控制，为灯链与触摸调试做准备。",
      parts: ["U5 · SN74LVC1T45", "U6 · TTP223-BA6", "R10 已在 S1"],
      steps: [
        "U5 SN74LVC1T45 对齐 pin 1，负责 LED 数据电平转换。",
        "U6 TTP223-BA6 对齐 pin 1，负责触摸输入。",
        "复核 S1 已安装的 R10 为 0Ω，它把触摸配置为高有效。",
        "放大检查 U5、U6 六只脚之间没有桥连。"
      ],
      checkpoint: "R10 不在本步安装，但必须已经在 S1 中完成。"
    },
    {
      id: "s5",
      code: "S5",
      count: "10 件",
      color: "#0891b2",
      title: "侧灯去耦 C40-C49",
      subtitle: "UNDERGLOW DECOUPLING",
      image: "stage-s5.zh-CN.png",
      summary: "透明版固定安装 10 颗 100 nF，为 10 颗侧发光 LED 分别去耦。",
      parts: ["C40-C49 · 100n 0402"],
      steps: [
        "先焊 C40-C49，共 10 颗 100 nF 0402。",
        "这些电容必须全部安装，不能在透明版中留空。",
        "每颗先固定一端，确认无立碑和偏移后再焊另一端。",
        "检查电容与即将安装的侧灯焊盘之间没有短路。"
      ],
      checkpoint: "先完成本步，再进入 S7 安装 LED15-LED24。"
    },
    {
      id: "s6",
      code: "S6",
      count: "14 件",
      color: "#d97706",
      title: "每键 LED1-LED14",
      subtitle: "REVERSE MOUNT RGB",
      image: "stage-s6.zh-CN.png",
      summary: "14 颗反装 SK6812MINI-E 组成主灯链，pin 1 方向决定整串是否工作。",
      parts: ["LED1-LED14 · SK6812MINI-E"],
      steps: [
        "先放好第一排 LED1-LED4，再依次完成 LED5-LED12。",
        "LED13 在 2U 轴位，LED14 是独立层指示位。",
        "每颗先固定对角两点，再焊另外两点；白圈标出 pad 1。",
        "全部焊完先目检方向，再上电测试灯链。"
      ],
      checkpoint: "一颗 LED 反装可能让后续整串都不亮。"
    },
    {
      id: "s7",
      code: "S7",
      count: "10 件",
      color: "#0e7490",
      title: "侧边 LED15-LED24",
      subtitle: "EDGE-FIRING RGB",
      image: "stage-s7.zh-CN.png",
      summary: "透明版固定安装 10 颗 SK6812-SIDE，沿 PCB 四周照亮扩散层。",
      parts: ["LED15-LED24 · SK6812-SIDE"],
      steps: [
        "上边焊 LED15、LED16；右边焊 LED17-LED19。",
        "下边焊 LED20、LED21；左边焊 LED22-LED24。",
        "按板上 pin 1 标记逐颗对齐，使用低风速热风避免吹飞。",
        "LED15、LED16 按设计朝外，不要自行旋转。"
      ],
      checkpoint: "先完成 S5 的 C40-C49，再焊本步侧灯。"
    },
    {
      id: "s8",
      code: "S8",
      count: "2 件",
      color: "#65a30d",
      title: "BOOT / RESET",
      subtitle: "TACTILE SWITCH",
      image: "stage-s8.zh-CN.png",
      summary: "焊 SW14 和 SW15，两个按键没有极性，但必须使用鸥翼脚版本。",
      parts: ["SW14 · BOOT", "SW15 · RESET", "PTS645SM43SMTR92 LFS"],
      steps: [
        "SW14 对应 BOOT，SW15 对应 RESET。",
        "使用 C&K PTS645SM43SMTR92 LFS，6.0 × 6.0 × H4.3。",
        "先对角固定两脚，确认按键平贴后再焊余下两脚。",
        "不要使用 J 引脚版本 PTS645SM43JSMTR92 LFS。"
      ],
      checkpoint: "按键歪斜会卡住外壳检修孔。"
    },
    {
      id: "s9",
      code: "S9",
      count: "13 件",
      color: "#b91c1c",
      title: "热插拔座 SW1-SW13",
      subtitle: "LAST BOTTOM SMD",
      image: "stage-s9.zh-CN.png",
      summary: "13 个 Kailh CPG151101S11 是底面最后一批；座体高、热容量大。",
      parts: ["SW1-SW13", "Kailh CPG151101S11"],
      steps: [
        "按底面左上开始：SW4→SW3→SW2→SW1，再完成第二排和第三排。",
        "每个座子先焊一端，确认平贴和中心孔位置后再焊另一端。",
        "座内不能进锡，不要用 MX 轴体当夹具在高温时强插。",
        "最后检查 13 个座子的方向都与丝印一致。"
      ],
      checkpoint: "真实 MX 轴体不焊，最后直接插入。"
    },
    {
      id: "s10",
      code: "S10",
      count: "2 件",
      color: "#be185d",
      title: "翻面焊顶面直插件",
      subtitle: "FLIP THE BOARD",
      image: "stage-s10.zh-CN.png",
      summary: "底面全部完成并清洁后翻面，最后焊编码器和摇杆。",
      parts: ["RE1 · PEC11R-4215F-S0024", "JS1 · YA13-FL7.4-B5Ka", "TP5 选装"],
      steps: [
        "干插 JS1 YA13 摇杆，确认 10 个焊点无应力进入。",
        "干插 RE1 EC11 编码器，确认 7 个焊点都能对齐。",
        "先焊两个对角脚，检查垂直、贴平、旋转和摇杆行程。",
        "确认后焊完所有信号脚与机械脚；TP5 只按触摸面板需要选装。"
      ],
      checkpoint: "翻面后不要再让板子压住编码器轴或摇杆。"
    }
  ];

  const steps = Array.isArray(window.AGENTPAD_STEPS) ? window.AGENTPAD_STEPS : [];
  const stages = steps.map((step) => ({
    ...step,
    id: step.id,
    code: step.code,
    count: step.count,
    color: step.color,
    title: step.title,
    subtitle: step.subtitle,
    image: step.image,
    summary: step.summary,
    parts: step.parts,
    steps: step.steps,
    checkpoint: step.checkpoint
  }));
  const stageColors = Object.fromEntries(stages.map((stage) => [stage.code, stage.color]));
  Object.assign(stageColors, { SX: "#6b7280", 机械: "#6b7280" });

  const storageKey = "agentpad13-translucent-progress-v3";
  const state = {
    progress: readStorage(storageKey, {}),
    phase: "all",
    sort: { key: "", direction: 1 },
    placements: Array.isArray(window.AGENTPAD_PLACEMENTS) ? window.AGENTPAD_PLACEMENTS : []
  };

  const elements = {
    stageStack: document.querySelector("#stageStack"),
    phaseRail: document.querySelector("#phaseRail"),
    progressText: document.querySelector("#progressText"),
    progressBar: document.querySelector("#progressBar"),
    resetProgress: document.querySelector("#resetProgress"),
    inventoryBody: document.querySelector("#inventoryBody"),
    inventorySearch: document.querySelector("#inventorySearch"),
    stageFilter: document.querySelector("#stageFilter"),
    sideFilter: document.querySelector("#sideFilter"),
    configFilter: document.querySelector("#configFilter"),
    tableCount: document.querySelector("#tableCount"),
    inventorySummary: document.querySelector("#inventorySummary"),
    imageDialog: document.querySelector("#mapDialog"),
    dialogImage: document.querySelector("#dialogImage"),
    dialogTitle: document.querySelector("#dialogTitle")
  };

  function readStorage(key, fallback) {
    try {
      const value = localStorage.getItem(key);
      return value ? JSON.parse(value) : fallback;
    } catch {
      return fallback;
    }
  }

  function writeStorage(key, value) {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      // The guide remains usable when browser storage is disabled.
    }
  }

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;");
  }

  function openImage(src, title, alt) {
    elements.dialogImage.src = src;
    elements.dialogImage.alt = alt;
    elements.dialogTitle.textContent = title;
    if (typeof elements.imageDialog.showModal === "function") {
      elements.imageDialog.showModal();
    }
  }

  function renderStages() {
    const visibleStages = state.phase === "all"
      ? stages
      : stages.filter((stage) => stage.phase === state.phase);
    elements.stageStack.innerHTML = visibleStages.map((stage, index) => {
      const checked = Boolean(state.progress[stage.id]);
      const imageAlt = `${stage.code} ${stage.title} 高亮位置图`;
      return `
        <article class="stage-card${checked ? " is-complete" : ""}" id="step-${stage.code}" style="--stage-color:${stage.color}" data-stage="${stage.id}" data-phase="${stage.phase}">
          <div class="stage-code">
            <span>${String(stage.index).padStart(2, "0")}</span>
            <strong>${stage.code}</strong>
            <small>${escapeHtml(stage.subtitle)}</small>
          </div>
          <div class="stage-summary">
            <div class="stage-eyebrow"><span>${escapeHtml(stage.count)}</span><span>${escapeHtml(stage.phaseTitle)} · ${escapeHtml(stage.subtitle)}</span></div>
            <h3>${escapeHtml(stage.title)}</h3>
            <p>${escapeHtml(stage.summary)}</p>
            <div class="part-chips">${stage.parts.map((part) => `<code>${escapeHtml(part)}</code>`).join("")}</div>
            <label class="stage-complete">
              <input type="checkbox" data-progress="${stage.id}" ${checked ? "checked" : ""}>
              <span>标记本阶段完成</span>
            </label>
          </div>
          <div class="stage-body">
            <ol>${stage.steps.map((step) => `<li>${escapeHtml(step)}</li>`).join("")}</ol>
            <div class="stage-checkpoint"><strong>CHECK</strong><span>${escapeHtml(stage.checkpoint)}</span></div>
          </div>
          <figure class="stage-visual">
            <button class="stage-image-button" type="button" data-image="${stage.image}" data-title="${escapeHtml(`${stage.code} · ${stage.title}`)}" data-alt="${escapeHtml(imageAlt)}">
              <img src="${stage.image}" alt="${escapeHtml(imageAlt)}">
              <span>点击全屏看图</span>
            </button>
            <figcaption>
              <strong>高亮框 = STEP ${stage.code} 本步焊接位置</strong>
              <span>本步只包含一种元件型号；右侧列出值、封装、位号和检查项。</span>
            </figcaption>
          </figure>
        </article>
      `;
    }).join("");

    elements.stageStack.querySelectorAll("[data-progress]").forEach((input) => {
      input.addEventListener("change", () => {
        state.progress[input.dataset.progress] = input.checked;
        writeStorage(storageKey, state.progress);
        input.closest(".stage-card").classList.toggle("is-complete", input.checked);
        updateProgress();
      });
    });

    elements.stageStack.querySelectorAll("[data-image]").forEach((button) => {
      button.addEventListener("click", () => {
        openImage(button.dataset.image, button.dataset.title, button.dataset.alt);
      });
    });
  }

  function renderPhaseRail() {
    const phases = [...new Map(stages.map((stage) => [stage.phase, stage.phaseTitle])).entries()];
    const buttons = [
      `<button type="button" data-phase-filter="all" class="${state.phase === "all" ? "is-active" : ""}" aria-pressed="${state.phase === "all"}">
        <span>ALL</span><b>${stages.length}</b><small>全部步骤</small>
      </button>`,
      ...phases.map(([phase, phaseTitle]) => {
        const count = stages.filter((stage) => stage.phase === phase).length;
        const sample = stages.find((stage) => stage.phase === phase);
        return `<button type="button" data-phase-filter="${phase}" class="${state.phase === phase ? "is-active" : ""}" aria-pressed="${state.phase === phase}" style="--phase-color:${sample.color}">
          <span>${phase}</span><b>${count}</b><small>${escapeHtml(phaseTitle)}</small>
        </button>`;
      })
    ];
    elements.phaseRail.innerHTML = buttons.join("");
    elements.phaseRail.querySelectorAll("[data-phase-filter]").forEach((button) => {
      button.addEventListener("click", () => {
        state.phase = button.dataset.phaseFilter;
        renderPhaseRail();
        renderStages();
      });
    });
  }

  function updateProgress() {
    const count = stages.filter((stage) => state.progress[stage.id]).length;
    elements.progressText.textContent = `${count} / ${stages.length}`;
    elements.progressBar.style.width = `${(count / stages.length) * 100}%`;
  }

  function populateFilters() {
    const order = ["S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9", "S10", "SX", "机械"];
    const stageOptions = [...new Set(state.placements.map((row) => row["阶段"]))].sort(
      (a, b) => order.indexOf(a) - order.indexOf(b)
    );
    elements.stageFilter.insertAdjacentHTML(
      "beforeend",
      stageOptions.map((stage) => `<option value="${escapeHtml(stage)}">${escapeHtml(stage)}</option>`).join("")
    );
  }

  function refSortValue(ref) {
    const match = ref.match(/(\d+)$/);
    return [ref.replace(/\d+$/, ""), match ? Number(match[1]) : 0];
  }

  function filteredPlacements() {
    const query = elements.inventorySearch.value.trim().toLowerCase();
    const stage = elements.stageFilter.value;
    const side = elements.sideFilter.value;
    const status = elements.configFilter.value;
    const filtered = state.placements.filter((row) => {
      if (stage && row["阶段"] !== stage) return false;
      if (side && row["面"] !== side) return false;
      if (status && row["配置"] !== status) return false;
      if (!query) return true;
      return [
        row["参考位号"],
        row["值/型号"],
        row["封装"],
        row["方向/极性"],
        row["说明"]
      ].some((value) => value.toLowerCase().includes(query));
    });

    if (state.sort.key) {
      filtered.sort((left, right) => {
        if (state.sort.key === "参考位号") {
          const a = refSortValue(left["参考位号"]);
          const b = refSortValue(right["参考位号"]);
          return (a[0].localeCompare(b[0]) || a[1] - b[1]) * state.sort.direction;
        }
        return String(left[state.sort.key]).localeCompare(String(right[state.sort.key]), "zh-CN", {
          numeric: true
        }) * state.sort.direction;
      });
    }
    return filtered;
  }

  function renderTable() {
    const rows = filteredPlacements();
    elements.tableCount.textContent = `${rows.length} 条`;
    elements.inventoryBody.innerHTML = rows.map((row) => {
      const statusClass =
        row["配置"] === "禁止安装" ? "is-dnp" :
        row["配置"] === "选装" ? "is-optional" : "";
      const color = stageColors[row["阶段"]] || "#4d514b";
      return `
        <tr class="${statusClass}">
          <td class="ref-cell">${escapeHtml(row["参考位号"])}</td>
          <td><span class="stage-badge" style="--badge-color:${color}">${escapeHtml(row["阶段"])}</span></td>
          <td>${escapeHtml(row["值/型号"])}</td>
          <td>${escapeHtml(row["封装"])}</td>
          <td><span class="side-pill">${escapeHtml(row["面"])}</span></td>
          <td>${escapeHtml(row["CPL_X_mm"])}</td>
          <td>${escapeHtml(row["CPL_Y_mm"])}</td>
          <td>${escapeHtml(row["方向/极性"])}</td>
          <td>${escapeHtml(row["说明"])}</td>
        </tr>
      `;
    }).join("");

    if (!rows.length) {
      elements.inventoryBody.innerHTML = `<tr><td colspan="9">没有匹配的记录。</td></tr>`;
    }
  }

  function bindEvents() {
    elements.resetProgress.addEventListener("click", () => {
      state.progress = {};
      writeStorage(storageKey, state.progress);
      renderStages();
      updateProgress();
    });

    elements.inventorySearch.addEventListener("input", renderTable);
    elements.stageFilter.addEventListener("change", renderTable);
    elements.sideFilter.addEventListener("change", renderTable);
    elements.configFilter.addEventListener("change", renderTable);

    document.querySelectorAll("[data-sort]").forEach((button) => {
      button.addEventListener("click", () => {
        const key = button.dataset.sort;
        state.sort.direction = state.sort.key === key ? -state.sort.direction : 1;
        state.sort.key = key;
        renderTable();
      });
    });

    document.querySelector("#closeMap").addEventListener("click", () => elements.imageDialog.close());
    elements.imageDialog.addEventListener("click", (event) => {
      if (event.target === elements.imageDialog) elements.imageDialog.close();
    });
    document.querySelector("#printButton").addEventListener("click", () => window.print());
  }

  function init() {
    renderPhaseRail();
    renderStages();
    updateProgress();
    populateFilters();
    renderTable();
    bindEvents();
    const installed = state.placements.filter((row) => row["配置"] === "透明版安装").length;
    const dnp = state.placements.filter((row) => row["配置"] === "禁止安装").length;
    const optional = state.placements.filter((row) => row["配置"] === "选装").length;
    elements.inventorySummary.textContent =
      `透明版 ${installed} 件安装、${dnp} 件禁止安装、${optional} 项选装。`;
  }

  init();
})();
