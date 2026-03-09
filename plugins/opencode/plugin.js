// cctop plugin for opencode
// Writes session state to ~/.cctop/sessions/{pid}.json for the cctop menubar app.
// Zero dependencies — runs in-process in Bun.

import { mkdirSync, writeFileSync, renameSync } from "fs";
import { join, basename } from "path";
import { homedir } from "os";
import { execSync } from "child_process";

const SESSIONS_DIR = join(homedir(), ".cctop", "sessions");
const PID = process.pid;
const SESSION_PATH = join(SESSIONS_DIR, `${PID}.json`);

// Tool name normalization: opencode lowercase -> CC PascalCase
const TOOL_NAME_MAP = {
  bash: "Bash",
  read: "Read",
  edit: "Edit",
  write: "Write",
  grep: "Grep",
  glob: "Glob",
  webfetch: "WebFetch",
  websearch: "WebSearch",
  task: "Task",
  question: "Question",
};

// Tool detail field extraction (mirrors HookHandler.extractToolDetail).
// Note: opencode uses camelCase args (filePath), Claude Code uses snake_case (file_path).
const TOOL_DETAIL_FIELD = {
  Bash: "command",
  Edit: "filePath",
  Write: "filePath",
  Read: "filePath",
  Grep: "pattern",
  Glob: "pattern",
  WebFetch: "url",
  WebSearch: "query",
  Task: "description",
};

const MAX_TOOL_DETAIL_LEN = 120;

function normalizeTool(name) {
  if (!name) return null;
  const lower = name.toLowerCase();
  if (TOOL_NAME_MAP[lower]) return TOOL_NAME_MAP[lower];
  // Capitalize first letter for unknown tools (future-proof)
  return name.charAt(0).toUpperCase() + name.slice(1);
}

function extractToolDetail(normalizedName, args) {
  if (!normalizedName || !args) return null;
  // Special case: Question tool has nested questions array
  if (normalizedName === "Question") {
    const questions = args.questions;
    if (Array.isArray(questions) && questions.length > 0) {
      return questions[0].header || questions[0].question || null;
    }
    return null;
  }
  const field = TOOL_DETAIL_FIELD[normalizedName];
  if (!field) return null;
  const value = args[field];
  if (!value || typeof value !== "string") return null;
  if (value.length > MAX_TOOL_DETAIL_LEN) {
    return value.slice(0, MAX_TOOL_DETAIL_LEN - 3) + "...";
  }
  return value;
}

function isoNow() {
  return new Date().toISOString();
}

function getGitBranch(cwd) {
  try {
    return execSync("git branch --show-current", {
      cwd,
      encoding: "utf8",
      timeout: 3000,
      stdio: ["pipe", "pipe", "pipe"],
    }).trim() || "unknown";
  } catch {
    return "unknown";
  }
}

function getTerminalInfo() {
  return {
    program: process.env.TERM_PROGRAM || "",
    session_id: process.env.ITERM_SESSION_ID || process.env.KITTY_WINDOW_ID || null,
    tty: process.env.TTY || null,
  };
}

function writeSession(session) {
  try {
    mkdirSync(SESSIONS_DIR, { recursive: true });
    const tmp = SESSION_PATH + ".tmp";
    writeFileSync(tmp, JSON.stringify(session, null, 2));
    renameSync(tmp, SESSION_PATH);
  } catch {
    // Best-effort — don't crash the opencode process
  }
}

// In-memory session state
let session = null;
// True while the question tool is blocking on user input.
// Prevents session.status "busy" and tool.execute.after from overriding waiting_input.
let questionPending = false;

function ensureSession(directory) {
  if (session) return;
  const branch = getGitBranch(directory);
  session = {
    session_id: `opencode-${PID}`,
    project_path: directory,
    project_name: basename(directory),
    branch,
    status: "idle",
    last_prompt: null,
    last_activity: isoNow(),
    started_at: isoNow(),
    terminal: getTerminalInfo(),
    pid: PID,
    pid_start_time: Math.floor(Date.now() / 1000 - process.uptime()),
    last_tool: null,
    last_tool_detail: null,
    notification_message: null,
    session_name: null,
    workspace_file: null,
    source: "opencode",
  };
}

function updateSession(updates) {
  if (!session) return;
  Object.assign(session, updates, { last_activity: isoNow() });
  writeSession(session);
}

function clearToolState() {
  if (!session) return;
  session.last_tool = null;
  session.last_tool_detail = null;
  session.notification_message = null;
}

export const cctop = async ({ directory }) => {
  ensureSession(directory);
  updateSession({ status: "idle" });

  return {
    event: async ({ event }) => {
      if (!event || !event.type) return;

      switch (event.type) {
        case "session.created":
          ensureSession(directory);
          clearToolState();
          updateSession({
            status: "idle",
            branch: getGitBranch(directory),
            session_id: event.id || session.session_id,
          });
          break;

        case "session.idle":
          questionPending = false;
          clearToolState();
          // opencode is always interactive; idle = waiting for user input
          updateSession({ status: "waiting_input" });
          break;

        case "session.error": {
          const errMsg = event.error?.message || event.message || null;
          updateSession({
            status: "needs_attention",
            notification_message: errMsg,
          });
          break;
        }

        case "session.compacted":
          updateSession({ status: "idle" });
          break;

        case "session.status": {
          // opencode nests the status type differently across versions
          const type = event.properties?.status?.type
            || event.properties?.type
            || event.status?.type;
          if (type === "busy") {
            // Don't override waiting states (question tool or permission request)
            if (!questionPending && session?.status !== "waiting_permission") {
              updateSession({ status: "working" });
            }
          } else if (type === "retry") {
            updateSession({ status: "needs_attention" });
          }
          // type === "idle" is handled by session.idle event — ignore here
          // to avoid overriding the waiting_input state
          break;
        }

        case "permission.replied":
          // Permission resolved (approved or denied) — agent will proceed
          questionPending = false;
          clearToolState();
          updateSession({ status: "working" });
          break;

        case "session.updated": {
          const title = event.properties?.info?.title;
          if (title) updateSession({ session_name: title });
          break;
        }

        case "session.deleted":
          // Let the menubar's liveness check handle cleanup
          break;
      }
    },

    "chat.message": async (_input, output) => {
      questionPending = false;
      clearToolState();
      const prompt = output?.message?.content
        || output?.content
        || (typeof output?.text === "string" ? output.text : null);
      const updates = { status: "working" };
      if (prompt) updates.last_prompt = prompt;
      updateSession(updates);
    },

    "tool.execute.before": async (_input, output) => {
      const tool = normalizeTool(output?.tool || _input?.tool);
      const args = output?.args || _input?.args;
      const detail = extractToolDetail(tool, args);
      // The "question" tool asks the user for input and blocks until they respond.
      // Treat it as waiting_input so the session shows as needing attention.
      const isQuestion = tool && tool.toLowerCase() === "question";
      questionPending = isQuestion;
      updateSession({
        status: isQuestion ? "waiting_input" : "working",
        last_tool: tool,
        last_tool_detail: detail,
        notification_message: isQuestion ? (detail || "Question pending") : session.notification_message,
      });
    },

    "tool.execute.after": async () => {
      // Don't override waiting_input if the question tool is still blocking.
      // The question tool's "after" fires when it returns (user answered),
      // but session.status "busy" or chat.message will follow to set working.
      if (questionPending) return;
      updateSession({ status: "working" });
    },

    "permission.ask": async (input, _output) => {
      const tool = normalizeTool(input?.tool);
      const detail = extractToolDetail(tool, input?.args);
      const msg = input?.title
        || (tool && detail ? `${tool}: ${detail}` : tool)
        || "Permission needed";
      updateSession({
        status: "waiting_permission",
        notification_message: msg,
        last_tool: null,
        last_tool_detail: null,
      });
    },

    "experimental.session.compacting": async () => {
      updateSession({ status: "compacting" });
    },
  };
};
