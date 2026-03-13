import { useEffect, useRef, useState } from 'react'
import './App.css'

/* ─── Sprite Animation Component ─── */

interface SpriteProps {
  src: string
  frames: number
  width: number
  height: number
  fps?: number
  scale?: number
  flip?: boolean
  className?: string
  style?: React.CSSProperties
}

function Sprite({ src, frames, width, height, fps = 6, scale = 2, flip = false, className = '', style = {} }: SpriteProps) {
  const [frame, setFrame] = useState(0)

  useEffect(() => {
    const interval = setInterval(() => {
      setFrame(f => (f + 1) % frames)
    }, 1000 / fps)
    return () => clearInterval(interval)
  }, [frames, fps])

  return (
    <div
      className={`sprite ${className}`}
      style={{
        width: width * scale,
        height: height * scale,
        backgroundImage: `url(${src})`,
        backgroundPosition: `-${frame * width * scale}px 0`,
        backgroundSize: `${width * frames * scale}px ${height * scale}px`,
        imageRendering: 'pixelated',
        transform: flip ? 'scaleX(-1)' : 'none',
        ...style,
      }}
    />
  )
}

/* ─── Wandering Cat on the IDE ─── */

interface WanderingCatProps {
  startX: number
  bottomY: number
  minX: number
  maxX: number
  delay?: number
}

function WanderingCat({ startX, bottomY, minX, maxX, delay = 0 }: WanderingCatProps) {
  const [pos, setPos] = useState({ x: startX, targetX: startX, flip: false })
  const [state, setState] = useState<'idle' | 'walking' | 'sleeping'>('idle')
  const [speechBubble, setSpeechBubble] = useState<string | null>(null)
  const rafRef = useRef<number>(0)
  const stateTimeRef = useRef(0)
  const delayRef = useRef(delay)
  const nextDecisionRef = useRef(2000 + delay)
  const stateRef = useRef<'idle' | 'walking' | 'sleeping'>('idle')

  const bubbles = useRef([
    "Need input!",
    "Allow bash?",
    "meow?",
    "Waiting...",
    "Hey!",
    "*purr*",
    "Review this?",
    "^C or allow?",
  ])

  // Keep ref in sync with state
  const setStateAndRef = (s: 'idle' | 'walking' | 'sleeping') => {
    stateRef.current = s
    setState(s)
  }

  useEffect(() => {
    let lastTime = performance.now()

    const tick = (now: number) => {
      const dt = now - lastTime
      lastTime = now
      stateTimeRef.current += dt

      if (delayRef.current > 0) {
        delayRef.current -= dt
        rafRef.current = requestAnimationFrame(tick)
        return
      }

      if (stateTimeRef.current > nextDecisionRef.current) {
        stateTimeRef.current = 0
        const roll = Math.random()
        if (roll < 0.4) {
          const newTarget = minX + Math.random() * (maxX - minX)
          setPos(p => ({ ...p, targetX: newTarget, flip: newTarget < p.x }))
          setStateAndRef('walking')
          nextDecisionRef.current = 3000 + Math.random() * 4000
        } else if (roll < 0.55) {
          setStateAndRef('sleeping')
          nextDecisionRef.current = 5000 + Math.random() * 5000
        } else {
          setStateAndRef('idle')
          nextDecisionRef.current = 2000 + Math.random() * 3000
          if (Math.random() < 0.4) {
            const msgs = bubbles.current
            const msg = msgs[Math.floor(Math.random() * msgs.length)]
            setSpeechBubble(msg)
            setTimeout(() => setSpeechBubble(null), 2500)
          }
        }
      }

      if (stateRef.current === 'walking') {
        setPos(p => {
          const dx = p.targetX - p.x
          if (Math.abs(dx) < 2) {
            setStateAndRef('idle')
            return p
          }
          const speed = 0.08 * dt
          return { ...p, x: p.x + Math.sign(dx) * Math.min(speed, Math.abs(dx)), flip: dx < 0 }
        })
      }

      rafRef.current = requestAnimationFrame(tick)
    }

    rafRef.current = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(rafRef.current)
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])

  const spriteMap = {
    idle: { src: '/sprites/idle.png', frames: 6, fps: 5 },
    walking: { src: '/sprites/running.png', frames: 6, fps: 8 },
    sleeping: { src: '/sprites/sleeping.png', frames: 4, fps: 3 },
  }

  const sprite = spriteMap[state]

  return (
    <div
      className="wandering-cat"
      style={{
        position: 'absolute',
        left: pos.x,
        bottom: bottomY,
      }}
    >
      {speechBubble && (
        <div className="speech-bubble">{speechBubble}</div>
      )}
      <Sprite
        src={sprite.src}
        frames={sprite.frames}
        width={64}
        height={64}
        fps={sprite.fps}
        scale={1.5}
        flip={pos.flip}
      />
    </div>
  )
}

/* ─── Typing Code Animation ─── */

function TypingCode() {
  const lines = [
    { indent: 0, text: 'async function deployAgent(config: AgentConfig) {', color: 'keyword' },
    { indent: 1, text: 'const session = await createSession(config);', color: 'normal' },
    { indent: 1, text: 'logger.info(`Starting ${session.name}...`);', color: 'string' },
    { indent: 1, text: '', color: 'normal' },
    { indent: 1, text: 'while (session.active) {', color: 'keyword' },
    { indent: 2, text: 'const task = await session.nextTask();', color: 'normal' },
    { indent: 2, text: 'if (task.requiresPermission) {', color: 'keyword' },
    { indent: 3, text: '// Cat runs to your cursor: "Allow bash?" ', color: 'comment' },
    { indent: 3, text: 'await requestApproval(task);', color: 'normal' },
    { indent: 2, text: '}', color: 'keyword' },
    { indent: 2, text: 'await task.execute();', color: 'normal' },
    { indent: 1, text: '}', color: 'keyword' },
    { indent: 0, text: '}', color: 'keyword' },
  ]

  const [visibleLines, setVisibleLines] = useState(0)

  useEffect(() => {
    if (visibleLines < lines.length) {
      const timeout = setTimeout(() => {
        setVisibleLines(v => v + 1)
      }, 400 + Math.random() * 600)
      return () => clearTimeout(timeout)
    } else {
      const timeout = setTimeout(() => {
        setVisibleLines(0)
      }, 6000)
      return () => clearTimeout(timeout)
    }
  }, [visibleLines, lines.length])

  return (
    <div className="code-block">
      {lines.slice(0, visibleLines).map((line, i) => (
        <div key={i} className={`code-line ${line.color}`}>
          <span className="line-number">{i + 1}</span>
          <span className="line-content">
            {'  '.repeat(line.indent)}{line.text}
            {i === visibleLines - 1 && <span className="cursor-blink">|</span>}
          </span>
        </div>
      ))}
      {visibleLines === 0 && (
        <div className="code-line normal">
          <span className="line-number">1</span>
          <span className="line-content"><span className="cursor-blink">|</span></span>
        </div>
      )}
    </div>
  )
}

/* ─── Fake IDE Component ─── */

function FakeIDE() {
  const containerRef = useRef<HTMLDivElement>(null)
  const [ideWidth, setIdeWidth] = useState(600)

  useEffect(() => {
    const el = containerRef.current
    if (!el) return
    const ro = new ResizeObserver(entries => {
      for (const entry of entries) {
        setIdeWidth(entry.contentRect.width)
      }
    })
    ro.observe(el)
    setIdeWidth(el.clientWidth)
    return () => ro.disconnect()
  }, [])

  const catMaxX = Math.max(ideWidth - 120, 100)

  return (
    <div className="ide-window" ref={containerRef}>
      <div className="ide-titlebar">
        <div className="ide-dots">
          <span className="dot red" />
          <span className="dot yellow" />
          <span className="dot green" />
        </div>
        <span className="ide-title">agent-project &mdash; deploy.ts</span>
        <div className="ide-titlebar-spacer" />
      </div>
      <div className="ide-toolbar">
        <div className="ide-tabs">
          <div className="ide-tab active">deploy.ts</div>
          <div className="ide-tab">config.ts</div>
          <div className="ide-tab">session.ts</div>
        </div>
      </div>
      <div className="ide-body">
        <div className="ide-sidebar">
          <div className="sidebar-item active">src/</div>
          <div className="sidebar-item indent">deploy.ts</div>
          <div className="sidebar-item indent">config.ts</div>
          <div className="sidebar-item indent">session.ts</div>
          <div className="sidebar-item">tests/</div>
          <div className="sidebar-item">package.json</div>
        </div>
        <div className="ide-editor">
          <TypingCode />
        </div>
      </div>
      <div className="ide-statusbar">
        <span className="status-item">
          <span className="status-dot green-dot" />
          3 agents running
        </span>
        <span className="status-item">TypeScript</span>
        <span className="status-item">UTF-8</span>
      </div>

      {/* Cats wandering on the IDE */}
      <WanderingCat startX={60} bottomY={-12} minX={10} maxX={catMaxX * 0.6} delay={0} />
      <WanderingCat startX={Math.min(250, catMaxX * 0.4)} bottomY={-12} minX={catMaxX * 0.15} maxX={catMaxX * 0.8} delay={2500} />
      <WanderingCat startX={Math.min(400, catMaxX * 0.7)} bottomY={-12} minX={catMaxX * 0.3} maxX={catMaxX} delay={5000} />
    </div>
  )
}

/* ─── Feature Card ─── */

function FeatureCard({ icon, title, description }: { icon: string; title: string; description: string }) {
  return (
    <div className="feature-card">
      <div className="feature-icon">{icon}</div>
      <h3>{title}</h3>
      <p>{description}</p>
    </div>
  )
}

/* ─── Status Badge Demo ─── */

function StatusBadges() {
  return (
    <div className="status-badges-demo">
      <div className="badge-row">
        <span className="demo-badge working">WORKING</span>
        <span className="badge-label">Agent is coding away</span>
      </div>
      <div className="badge-row">
        <span className="demo-badge waiting">WAITING</span>
        <span className="badge-label">Needs your input</span>
      </div>
      <div className="badge-row">
        <span className="demo-badge permission">PERMISSION</span>
        <span className="badge-label">Allow bash: npm test?</span>
      </div>
      <div className="badge-row">
        <span className="demo-badge idle">IDLE</span>
        <span className="badge-label">Session complete</span>
      </div>
    </div>
  )
}

/* ─── Main App ─── */

function App() {
  return (
    <div className="app">
      {/* Nav */}
      <nav className="nav">
        <div className="nav-inner">
          <div className="nav-brand">
            <img src="/app-icon.png" alt="Nekode" className="nav-icon" />
            <span className="nav-name">Nekode</span>
          </div>
          <div className="nav-links">
            <a href="#features">Features</a>
            <a href="#pricing">Pricing</a>
            <a href="https://github.com/jakobserlier/nekode" target="_blank" rel="noopener">GitHub</a>
            <a href="#pricing" className="nav-cta">Get It</a>
          </div>
        </div>
      </nav>

      {/* Hero */}
      <section className="hero">
        <div className="hero-content">
          <div className="hero-badge">macOS menubar app</div>
          <h1>
            Your AI agents are working.<br />
            <span className="highlight">You shouldn't have to watch them.</span>
          </h1>
          <p className="hero-sub">
            Desktop pixel-art cats that monitor your Claude Code, opencode, and Copilot sessions.
            They sleep when idle. They run to you when something needs attention.
          </p>
          <div className="hero-actions">
            <a href="#pricing" className="btn btn-primary">
              Get Nekode &mdash; &euro;9.99
            </a>
            <a href="https://github.com/jakobserlier/nekode/releases" className="btn btn-secondary" target="_blank" rel="noopener">
              Download Free Trial
            </a>
          </div>
          <p className="hero-note">One-time purchase. No subscription. Full app, forever.</p>
        </div>

        <div className="hero-visual">
          <FakeIDE />
        </div>
      </section>

      {/* Social Proof / Quick Stats */}
      <section className="pitch">
        <div className="pitch-inner">
          <div className="pitch-item">
            <span className="pitch-number">3</span>
            <span className="pitch-label">AI agents supported</span>
          </div>
          <div className="pitch-divider" />
          <div className="pitch-item">
            <span className="pitch-number">0</span>
            <span className="pitch-label">Network requests</span>
          </div>
          <div className="pitch-divider" />
          <div className="pitch-item">
            <span className="pitch-number">100%</span>
            <span className="pitch-label">Local & private</span>
          </div>
          <div className="pitch-divider" />
          <div className="pitch-item">
            <span className="pitch-number">6</span>
            <span className="pitch-label">Cat colors</span>
          </div>
        </div>
      </section>

      {/* Features */}
      <section id="features" className="features">
        <div className="section-header">
          <h2>Everything at a glance</h2>
          <p>Stop alt-tabbing to check if your AI finished. Let the cats tell you.</p>
        </div>

        <div className="features-grid">
          <FeatureCard
            icon="/"
            title="Menubar Dashboard"
            description="Every AI coding session in one floating panel. Color-coded status badges show what each agent is doing right now."
          />
          <FeatureCard
            icon="~"
            title="Desktop Pets"
            description="Pixel-art cats live on your desktop. They sleep when idle, walk around when working, and sprint to your cursor when they need attention."
          />
          <FeatureCard
            icon=">"
            title="Jump to Any Session"
            description="Click a session to raise the exact VS Code, Cursor, or iTerm2 tab. Keyboard shortcuts and numbered badges for power users."
          />
          <FeatureCard
            icon="|"
            title="nekode wait CLI"
            description="Pipe any command through nekode wait. Your cat monitors the build and tells you when it's done. cargo build | nekode"
          />
          <FeatureCard
            icon="#"
            title="Fully Private"
            description="Zero network access. Zero analytics. Zero telemetry. All data stays in ~/.nekode/sessions/ as plain JSON."
          />
          <FeatureCard
            icon="*"
            title="Lightweight"
            description="Native Swift. No Electron. No web views. Under 5MB. Sits in your menubar and uses negligible resources."
          />
        </div>
      </section>

      {/* How it works */}
      <section className="how-it-works">
        <div className="section-header">
          <h2>How it works</h2>
          <p>No servers. No accounts. Just local files.</p>
        </div>
        <div className="how-steps">
          <div className="how-step">
            <div className="step-number">1</div>
            <h3>Install the hooks</h3>
            <p>
              <code>nekode hook</code> for Claude Code, a JS plugin for opencode, or <code>nekode wait</code> for any CLI command.
            </p>
          </div>
          <div className="how-step">
            <div className="step-number">2</div>
            <h3>Sessions appear</h3>
            <p>
              Hooks write JSON to <code>~/.nekode/sessions/</code>. The menubar app watches this directory. That's it.
            </p>
          </div>
          <div className="how-step">
            <div className="step-number">3</div>
            <h3>Cats do the rest</h3>
            <p>
              Desktop pets spawn per session. They mirror the agent's state. Double-click a cat to jump to its session.
            </p>
          </div>
        </div>
      </section>

      {/* Status badges section */}
      <section className="statuses-section">
        <div className="statuses-layout">
          <div className="statuses-text">
            <h2>Know what every agent is doing</h2>
            <p>
              Color-coded status badges tell you instantly. No need to check each terminal.
              Your cats change behavior to match &mdash; sleeping, walking, running, or spinning.
            </p>
            <StatusBadges />
          </div>
          <div className="statuses-visual">
            <img src="/menubar-dark.png" alt="Nekode menubar panel" className="screenshot" />
          </div>
        </div>
      </section>

      {/* Pricing */}
      <section id="pricing" className="pricing">
        <div className="section-header">
          <h2>Simple pricing</h2>
          <p>One app. One price. Yours forever.</p>
        </div>
        <div className="pricing-card">
          <div className="pricing-header-area">
            <div className="pricing-cats">
              <Sprite src="/sprites/idle.png" frames={6} width={64} height={64} fps={4} scale={1.5} />
              <Sprite src="/sprites/happy.png" frames={10} width={64} height={64} fps={5} scale={1.5} />
              <Sprite src="/sprites/idle.png" frames={6} width={64} height={64} fps={4} scale={1.5} flip />
            </div>
            <div className="price">
              <span className="currency">&euro;</span>
              <span className="amount">9</span>
              <span className="cents">.99</span>
            </div>
            <p className="price-note">One-time payment. Lifetime license.</p>
          </div>
          <ul className="pricing-features">
            <li>Full app with all features</li>
            <li>Desktop pets (6 cat colors)</li>
            <li>Claude Code, opencode &amp; Copilot support</li>
            <li>nekode wait CLI for any command</li>
            <li>Raycast extension included</li>
            <li>Free updates forever</li>
            <li>No subscription, no account needed</li>
          </ul>
          <button className="btn btn-primary btn-large" id="buy-button">
            Purchase License
          </button>
          <p className="pricing-note">
            Or <a href="https://github.com/jakobserlier/nekode/releases">download the free trial</a> &mdash; full functionality, gentle nag banner.
          </p>
        </div>
      </section>

      {/* Install */}
      <section className="install-section">
        <div className="section-header">
          <h2>Install in seconds</h2>
        </div>
        <div className="install-options">
          <div className="install-option">
            <h3>Homebrew</h3>
            <div className="code-snippet">
              <code>brew tap jakobserlier/nekode</code>
              <code>brew install --cask nekode</code>
            </div>
          </div>
          <div className="install-option">
            <h3>Shell</h3>
            <div className="code-snippet">
              <code>curl -fsSL https://nekode.dev/install.sh | bash</code>
            </div>
          </div>
          <div className="install-option">
            <h3>Direct Download</h3>
            <p>Download the <code>.dmg</code> from GitHub Releases.</p>
            <a href="https://github.com/jakobserlier/nekode/releases" className="btn btn-secondary btn-small" target="_blank" rel="noopener">
              GitHub Releases
            </a>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="footer">
        <div className="footer-inner">
          <div className="footer-brand">
            <img src="/app-icon.png" alt="Nekode" className="footer-icon" />
            <span>Nekode</span>
          </div>
          <div className="footer-links">
            <a href="https://github.com/jakobserlier/nekode" target="_blank" rel="noopener">GitHub</a>
            <a href="https://github.com/jakobserlier/nekode/releases" target="_blank" rel="noopener">Releases</a>
            <a href="https://github.com/jakobserlier/nekode/blob/main/LICENSE" target="_blank" rel="noopener">MIT License</a>
          </div>
          <p className="footer-copy">Built with questionable amounts of coffee and pixel art.</p>
        </div>
      </footer>
    </div>
  )
}

export default App
