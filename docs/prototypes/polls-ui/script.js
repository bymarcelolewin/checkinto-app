// ---------- Mock data: 3 polls covering all per-poll states ----------
const polls = [
  {
    id: "p1",
    title: "Vote for your favorite project",
    status: "open",
    top_n_winners: 3,
    show_vote_count: false,
    thanks_message: "Thanks for voting! Stay tuned for the winners.",
    closed_message: "Voting has closed for this poll.",
    no_votes_message: "No votes were recorded.",
    items: [
      { id: "i1a", name: "John's Project" },
      { id: "i1b", name: "Jan's Project" },
      { id: "i1c", name: "Dan's Project" },
      { id: "i1d", name: "Marcelo's Project" }
    ],
    my_vote_item_id: null,
    winner_labels: {},
    results: null
  },
  {
    id: "p2",
    title: "Best live demo",
    status: "open",
    top_n_winners: 3,
    show_vote_count: false,
    thanks_message: "Thanks! We'll show the winner after the panel wraps.",
    closed_message: "Voting has closed for this poll.",
    no_votes_message: "No votes were recorded.",
    items: [
      { id: "i2a", name: "Real-time transcription" },
      { id: "i2b", name: "Code review bot" },
      { id: "i2c", name: "AI dungeon master" }
    ],
    my_vote_item_id: "i2b",
    winner_labels: {},
    results: null
  },
  {
    id: "p3",
    title: "MVP of the night",
    status: "closed",
    top_n_winners: 3,
    show_vote_count: true,
    thanks_message: "Thanks for voting!",
    closed_message: "Voting has closed.",
    no_votes_message: "No votes were recorded.",
    items: [
      { id: "i3a", name: "Alex" },
      { id: "i3b", name: "Priya" },
      { id: "i3c", name: "Sam" },
      { id: "i3d", name: "Diego" }
    ],
    my_vote_item_id: "i3b",
    winner_labels: { "1": "Grand Champion", "2": "Runner-Up", "3": "Honorable Mention" },
    results: [
      { poll_item_id: "i3a", name: "Alex",  vote_count: 12, rank: 1, is_my_vote: false },
      { poll_item_id: "i3b", name: "Priya", vote_count:  9, rank: 2, is_my_vote: true  },
      { poll_item_id: "i3d", name: "Diego", vote_count:  9, rank: 2, is_my_vote: false },
      { poll_item_id: "i3c", name: "Sam",   vote_count:  4, rank: 4, is_my_vote: false }
    ]
  }
];

// Track which un-voted polls we've auto-popped this session (so closing doesn't immediately re-pop)
const autoPoppedThisSession = new Set();

// ---------- Helpers ----------
function ordinal(n) {
  const s = ["th", "st", "nd", "rd"];
  const v = n % 100;
  return n + (s[(v - 20) % 10] || s[v] || s[0]) + " Place";
}
function labelForRank(poll, rank) {
  return poll.winner_labels[String(rank)] || ordinal(rank);
}
function showVoteCounts() { return document.getElementById("toggle-vote-counts").checked; }
function autoPopupEnabled() { return document.getElementById("toggle-auto-popup").checked; }
function showDonation() { return document.getElementById("toggle-donation").checked; }
function showEventDetails() { return document.getElementById("toggle-event-details").checked; }

function pollState(poll) {
  if (poll.status === "closed") return "closed";
  if (poll.my_vote_item_id)     return "voted";
  return "unvoted";
}

// ---------- Inbox row rendering ----------
function renderInboxRow(poll) {
  const row = document.createElement("div");
  row.className = "inbox-row";
  const state = pollState(poll);

  let pill = "";
  if (state === "unvoted") pill = '<span class="inbox-pill inbox-pill-vote">Vote</span>';
  if (state === "voted")   pill = '<span class="inbox-pill inbox-pill-voted">Voted</span>';
  if (state === "closed")  pill = '<span class="inbox-pill inbox-pill-closed">Results</span>';

  let sub = "";
  if (state === "unvoted") sub = `${poll.items.length} option${poll.items.length === 1 ? "" : "s"} — tap to vote`;
  if (state === "voted")   sub = "Tap to view or change your vote";
  if (state === "closed")  sub = "Tap to see the winners";

  row.innerHTML = `
    <div>
      <div class="inbox-row-title">${poll.title}</div>
      <div class="inbox-row-sub">${sub}</div>
    </div>
    <div class="inbox-row-cta">${pill}<span class="inbox-chevron">›</span></div>
  `;
  row.addEventListener("click", () => openPopup(poll.id));
  return row;
}

// ---------- Popup body rendering (per state) ----------
function renderPopupBody(poll) {
  const wrap = document.createElement("div");
  wrap.innerHTML = `<h2 class="poll-title" style="margin:0 0 14px;font-size:18px;">${poll.title}</h2>`;

  if (poll.status === "open" && !poll.my_vote_item_id) {
    wrap.appendChild(renderBallot(poll));
  } else if (poll.status === "open" && poll.my_vote_item_id) {
    wrap.appendChild(renderVotedView(poll));
  } else if (poll.status === "closed") {
    wrap.appendChild(renderResults(poll));
  }
  return wrap;
}

function renderBallot(poll) {
  const c = document.createElement("div");
  poll.items.forEach(item => {
    const lbl = document.createElement("label");
    lbl.className = "ballot-item";
    lbl.innerHTML = `<input type="radio" name="ballot-${poll.id}" value="${item.id}" /><span class="ballot-item-name">${item.name}</span>`;
    c.appendChild(lbl);
  });
  const btn = document.createElement("button");
  btn.className = "btn btn-vote";
  btn.textContent = "Vote";
  btn.addEventListener("click", () => {
    const checked = c.querySelector(`input[name="ballot-${poll.id}"]:checked`);
    if (!checked) { alert("Pick one first 🙂"); return; }
    poll.my_vote_item_id = checked.value;
    closePopup();
    rerender();
  });
  c.appendChild(btn);
  return c;
}

function renderVotedView(poll) {
  const c = document.createElement("div");
  c.className = "thanks-state";
  c.innerHTML = `<p>${poll.thanks_message}</p>`;
  // Show the items with the one they picked highlighted
  poll.items.forEach(item => {
    const isPick = item.id === poll.my_vote_item_id;
    const row = document.createElement("div");
    row.className = "result-item" + (isPick ? " your-pick" : "");
    row.innerHTML = `<div><div class="result-name">${item.name}${isPick ? '<span class="your-pick-badge">Your pick</span>' : ""}</div></div>`;
    c.appendChild(row);
  });
  const changeBtn = document.createElement("button");
  changeBtn.className = "thanks-link";
  changeBtn.textContent = "Change your vote";
  changeBtn.style.marginTop = "10px";
  changeBtn.addEventListener("click", () => {
    poll.my_vote_item_id = null;
    closePopup();
    openPopup(poll.id); // reopen with ballot
  });
  c.appendChild(changeBtn);
  return c;
}

function renderResults(poll) {
  const c = document.createElement("div");

  if (!poll.results || poll.results.length === 0) {
    c.innerHTML = `<p class="muted" style="text-align:center;padding:16px;">${poll.no_votes_message}</p>`;
    return c;
  }

  const ranksCount = poll.results.reduce((acc, r) => {
    acc[r.rank] = (acc[r.rank] || 0) + 1;
    return acc;
  }, {});

  poll.results.forEach(r => {
    const tied = ranksCount[r.rank] > 1;
    const rankLabel = labelForRank(poll, r.rank) + (tied ? " — Tie" : "");
    const pickBadge = r.is_my_vote ? '<span class="your-pick-badge">Your pick</span>' : "";
    const count = showVoteCounts() ? `<div class="result-count">${r.vote_count} votes</div>` : "";

    const row = document.createElement("div");
    row.className = "result-item" + (r.is_my_vote ? " your-pick" : "");
    row.innerHTML = `
      <div>
        <div class="result-rank">${rankLabel}</div>
        <div class="result-name">${r.name}${pickBadge}</div>
      </div>
      ${count}
    `;
    c.appendChild(row);
  });

  return c;
}

// ---------- Popup open/close ----------
function openPopup(pollId) {
  console.log("[prototype] openPopup", pollId);
  const poll = polls.find(p => p.id === pollId);
  if (!poll) return;
  const overlay = document.getElementById("popup-overlay");
  const body = document.getElementById("popup-body");
  body.innerHTML = "";
  body.appendChild(renderPopupBody(poll));

  overlay.hidden = false;
  setStatus(currentStateLine() + `\npopup:    ${pollId} (${pollState(poll)})`);
}
function closePopup(source) {
  console.log("[prototype] closePopup via", source || "unknown");
  document.getElementById("popup-overlay").hidden = true;
  setStatus(currentStateLine() + `\npopup:    (closed via ${source || "unknown"})`);
}

// ---------- Master rerender ----------
function setStatus(msg, isError) {
  const el = document.getElementById("debug-status");
  if (!el) return;
  el.textContent = msg;
  el.classList.toggle("error", !!isError);
}

function currentStateLine() {
  const states = polls.map(p => `${p.id}:${pollState(p)}`).join("  ");
  return `polls:    ${states}\ncounts:   ${showVoteCounts() ? "on" : "off"}`;
}

function rerender() {
  try {
    setStatus(currentStateLine());

    // Toggle donation + event details visibility per checkboxes
    document.getElementById("donation-card").hidden  = !showDonation();
    document.getElementById("event-details").hidden  = !showEventDetails();

    // Render inbox card (only show inbox if there are any polls in any state)
    const inboxCard = document.getElementById("polls-inbox");
    const list = document.getElementById("inbox-list");
    list.innerHTML = "";
    if (polls.length === 0) {
      inboxCard.hidden = true;
    } else {
      inboxCard.hidden = false;
      polls.forEach(p => list.appendChild(renderInboxRow(p)));
    }
  } catch (err) {
    setStatus("error: " + (err && err.message ? err.message : String(err)), true);
    throw err;
  }
}

// ---------- Auto-popup logic ----------
function maybeAutoPopup() {
  if (!autoPopupEnabled()) return;
  const target = polls.find(p => p.status === "open" && !p.my_vote_item_id && !autoPoppedThisSession.has(p.id));
  if (target) {
    autoPoppedThisSession.add(target.id);
    openPopup(target.id);
  }
}

// ---------- Dev panel events ----------
const devPanelEl = document.querySelector(".dev-panel");
["change", "input"].forEach(evt => {
  devPanelEl.addEventListener(evt, (e) => {
    if (!e.target) return;
    if (e.target.tagName === "INPUT") rerender();
  });
});

document.getElementById("btn-close-poll-1").addEventListener("click", () => {
  const p = polls.find(x => x.id === "p1"); if (!p) return;
  p.status = "closed";
  // Mock some results so the closed view has content
  p.results = [
    { poll_item_id: "i1a", name: "John's Project",     vote_count: 14, rank: 1, is_my_vote: p.my_vote_item_id === "i1a" },
    { poll_item_id: "i1b", name: "Jan's Project",      vote_count: 11, rank: 2, is_my_vote: p.my_vote_item_id === "i1b" },
    { poll_item_id: "i1c", name: "Dan's Project",      vote_count: 11, rank: 2, is_my_vote: p.my_vote_item_id === "i1c" },
    { poll_item_id: "i1d", name: "Marcelo's Project",  vote_count:  5, rank: 4, is_my_vote: p.my_vote_item_id === "i1d" }
  ];
  rerender();
});

document.getElementById("btn-reopen-poll-3").addEventListener("click", () => {
  const p = polls.find(x => x.id === "p3"); if (!p) return;
  p.status = "open";
  p.results = null;
  rerender();
});

document.getElementById("btn-reset-votes").addEventListener("click", () => {
  polls.forEach(p => { p.my_vote_item_id = null; });
  autoPoppedThisSession.clear();
  rerender();
  maybeAutoPopup();
});

document.getElementById("btn-reload-popup").addEventListener("click", () => {
  autoPoppedThisSession.clear();
  maybeAutoPopup();
});

// X button — close
document.getElementById("popup-close").addEventListener("click", (e) => {
  e.stopPropagation();
  closePopup("X button");
});
// Dim overlay — clicking anywhere on it closes; popup-card stops propagation so card clicks don't bubble here
document.getElementById("popup-overlay").addEventListener("click", () => closePopup("overlay click"));
document.getElementById("popup-card").addEventListener("click", (e) => e.stopPropagation());
// Escape key — close
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !document.getElementById("popup-overlay").hidden) {
    closePopup("Escape key");
  }
});

// Manual popup controls (dev panel)
document.getElementById("btn-open-p1").addEventListener("click", () => openPopup("p1"));
document.getElementById("btn-open-p2").addEventListener("click", () => openPopup("p2"));
document.getElementById("btn-open-p3").addEventListener("click", () => openPopup("p3"));
document.getElementById("btn-close-popup").addEventListener("click", () => closePopup("dev panel"));

// First render + auto-popup
rerender();
maybeAutoPopup();
