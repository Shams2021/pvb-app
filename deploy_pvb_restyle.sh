#!/bin/bash
set -e
APP=/opt/bvp-app/frontend
echo "Backing up current frontend..."
cp -r "$APP" "$APP.backup-$(date +%F-%H%M)"
mkdir -p "$APP/src/components" "$APP/src/context" "$APP/src/pages" "$APP/src/assets"

echo "Writing tailwind.config.js..."
cat > "$APP/tailwind.config.js" << 'PVBEOF'
/** @type {import('tailwindcss').Config} */
export default {
  // 'class' strategy = we toggle dark mode by adding/removing `dark` on <html>.
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{js,jsx,ts,tsx}'],
  theme: {
    extend: {
      colors: {
        // PVB Werkbank palette — origineel, geïnspireerd op servicedesk/ticket-systemen.
        carbon: { DEFAULT: '#181C1E', 900: '#101314', 800: '#20262A' },
        paper: '#EEF1EE',
        ink: { 900: '#1B211F', 700: '#3E4A46', 500: '#68746F' },
        amber: { DEFAULT: '#E2962F', 600: '#C97F1E' },
        moss: '#4C8C5B',
        rust: '#B85C38',
      },
      fontFamily: {
        display: ['"Space Grotesk"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        sans: ['"IBM Plex Sans"', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      transitionTimingFunction: {
        // vlakke, precieze ease-out — geen bounce
        crisp: 'cubic-bezier(0.16, 1, 0.3, 1)',
      },
      backgroundImage: {
        // subtiele stippen-textuur voor de sidebar, als een geperforeerde ticketrand
        perforation:
          'repeating-linear-gradient(to bottom, transparent 0 6px, rgba(255,255,255,0.12) 6px 7px)',
      },
    },
  },
  plugins: [],
};

PVBEOF

echo "Writing src/index.css..."
cat > "$APP/src/index.css" << 'PVBEOF'
@import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=IBM+Plex+Sans:wght@400;500;600;700&family=JetBrains+Mono:wght@500;600&display=swap');

@tailwind base;
@tailwind components;
@tailwind utilities;

/* App defaults. The `dark` class on <html> flips the palette (see ThemeContext). */
html {
  font-family: 'IBM Plex Sans', sans-serif;
}
body {
  margin: 0;
  @apply bg-paper text-ink-900 antialiased;
}
html.dark body {
  @apply bg-carbon text-white;
}

h1, h2, h3, .font-display {
  font-family: 'Space Grotesk', sans-serif;
}

/* Eyebrow label above headings */
.eyebrow {
  @apply font-mono text-[11px] font-medium uppercase tracking-[0.14em] text-amber;
}

/* Ticket-nummer: klein monospace label, gebruikt op kaarten en in de wizard-header */
.ticket-id {
  @apply font-mono text-[11px] tracking-wide text-ink-500 dark:text-white/40;
}

PVBEOF

echo "Writing src/main.jsx..."
cat > "$APP/src/main.jsx" << 'PVBEOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import App from './App';
import { ThemeProvider } from './context/ThemeContext';
import './index.css';
ReactDOM.createRoot(document.getElementById('root')).render(
  <ThemeProvider>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </ThemeProvider>
);

PVBEOF

echo "Writing src/App.jsx..."
cat > "$APP/src/App.jsx" << 'PVBEOF'
import React from 'react';
import { Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './context/AuthContext';
import Login from './pages/Login';
import Dashboard from './pages/Dashboard';
import FormulierInvullen from './pages/FormulierInvullen';
import DocentDashboard from './pages/DocentDashboard';
import OpdrachtenBeheer from './pages/OpdrachtenBeheer';
function Laden() {
  return (
    <div className="flex items-center justify-center h-screen bg-paper dark:bg-carbon">
      <p className="text-ink-500 dark:text-white/50 text-lg font-mono">Laden…</p>
    </div>
  );
}
function PrivateRoute({ children, role }) {
  const { user, loading } = useAuth();
  if (loading) return <Laden />;
  if (!user) return <Navigate to="/" replace />;
  if (role && user.rol !== role) return <Navigate to="/dashboard" replace />;
  return children;
}
function AppInner() {
  const { loading } = useAuth();
  if (loading) return <Laden />;
  return (
    <Routes>
      <Route path="/" element={<Login />} />
      <Route path="/dashboard" element={<PrivateRoute><Dashboard /></PrivateRoute>} />
      <Route path="/formulier/nieuw" element={<PrivateRoute><FormulierInvullen /></PrivateRoute>} />
      <Route path="/docent" element={<PrivateRoute role="docent"><DocentDashboard /></PrivateRoute>} />
      <Route path="/docent/opdrachten" element={<PrivateRoute role="docent"><OpdrachtenBeheer /></PrivateRoute>} />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
export default function App() {
  return (
    <AuthProvider>
      <AppInner />
    </AuthProvider>
  );
}

PVBEOF

echo "Writing src/context/ThemeContext.jsx..."
cat > "$APP/src/context/ThemeContext.jsx" << 'PVBEOF'
import { createContext, useContext, useEffect, useState } from 'react';

const ThemeContext = createContext({ theme: 'dark', setTheme: () => {} });

/**
 * Wrap de hele app in <ThemeProvider> (in main.jsx, om <AuthProvider> heen).
 * - Donker is de standaard voor nieuwe bezoekers.
 * - De keuze wordt onthouden in localStorage onder 'pvb-theme'.
 * - Wisselen zet/verwijdert de `dark` class op <html>, die alle Tailwind
 *   `dark:`-varianten in de app aanstuurt.
 */
export function ThemeProvider({ children }) {
  const [theme, setTheme] = useState(() => {
    if (typeof window === 'undefined') return 'dark';
    return localStorage.getItem('pvb-theme') || 'dark';
  });

  useEffect(() => {
    document.documentElement.classList.toggle('dark', theme === 'dark');
    localStorage.setItem('pvb-theme', theme);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}

export const useTheme = () => useContext(ThemeContext);

PVBEOF

echo "Writing src/components/Layout.jsx..."
cat > "$APP/src/components/Layout.jsx" << 'PVBEOF'
import { NavLink } from 'react-router-dom';
import { FileCheck2, Table2, ListChecks, LogOut } from 'lucide-react';
import logo from '../assets/pvb-logo.png';
import ThemeToggle from './ThemeToggle';
import { useAuth } from '../context/AuthContext';

/**
 * App-shell: donkere carbon-sidebar (altijd donker, in beide thema's) + een werkvlak
 * dat wisselt tussen licht en donker. Vervangt de losse <Navbar />: haalt de
 * ingelogde gebruiker rechtstreeks uit AuthContext, dus geen aparte user-prop nodig.
 *
 * Props:
 *   role   — 'student' | 'docent'   (bepaalt welke navigatie-items tonen)
 *   title  — string, getoond in de topbalk
 *   right  — optioneel element uiterst rechts in de topbalk (bijv. een "Nieuw"-knop)
 */
const studentNav = [
  { to: '/dashboard', icon: FileCheck2, label: 'Mijn afspraken', end: true },
];
const docentNav = [
  { to: '/docent', icon: Table2, label: 'Formulieren', end: true },
  { to: '/docent/opdrachten', icon: ListChecks, label: 'Opdrachten' },
];

function NavItem({ to, icon: Icon, label, end }) {
  return (
    <NavLink
      to={to}
      end={end}
      className={({ isActive }) =>
        `flex items-center gap-2.5 rounded px-2.5 py-2.5 text-[13px] transition-colors duration-150 ease-crisp ${
          isActive
            ? 'bg-amber/15 font-semibold text-amber'
            : 'font-medium text-white/65 hover:text-white'
        }`
      }
    >
      <Icon size={17} strokeWidth={1.75} /> {label}
    </NavLink>
  );
}

export default function Layout({ role = 'student', title, right, children }) {
  const { user, logout } = useAuth();
  const nav = role === 'docent' ? docentNav : studentNav;
  const naam = user?.naam || '…';
  const initials = naam
    .split(' ')
    .map((w) => w[0])
    .slice(0, 2)
    .join('')
    .toUpperCase();

  return (
    <div className="grid h-screen grid-cols-[236px_1fr] overflow-hidden font-sans">
      {/* Sidebar — altijd carbon, met geperforeerde rand rechts */}
      <aside className="relative flex flex-col bg-carbon px-3.5 py-4">
        <div className="pointer-events-none absolute right-0 top-0 h-full w-px bg-perforation" />

        <div className="flex items-center gap-3 px-2 pb-5 pt-1.5">
          <img src={logo} alt="PVB" className="h-9 w-9 rounded bg-white object-contain" />
          <div>
            <div className="font-display text-sm font-bold leading-none text-white">PVB</div>
            <div className="mt-1 font-mono text-[10px] tracking-wide text-white/40">Examenafspraken</div>
          </div>
        </div>

        <div className="px-2.5 py-1.5 font-mono text-[10px] uppercase tracking-[0.14em] text-white/35">
          {role === 'docent' ? 'Docent' : 'Student'}
        </div>

        <nav className="flex flex-col gap-0.5">
          {nav.map((n) => <NavItem key={n.to} {...n} />)}
        </nav>

        <div className="mt-auto flex items-center gap-2.5 border-t border-white/10 pt-3">
          <span className="flex h-8 w-8 items-center justify-center rounded-full border border-amber/40 font-mono text-[11px] font-semibold text-amber">
            {initials || '?'}
          </span>
          <div className="min-w-0 flex-1">
            <div className="truncate text-xs font-semibold text-white">{naam}</div>
            <div className="text-[11px] capitalize text-white/45">{user?.rol}</div>
          </div>
          <button onClick={logout} aria-label="Uitloggen">
            <LogOut size={16} strokeWidth={1.75} className="text-white/45 hover:text-white" />
          </button>
        </div>
      </aside>

      {/* Werkvlak — wisselt licht/donker */}
      <div className="flex flex-col overflow-hidden bg-paper transition-colors duration-200 ease-crisp dark:bg-carbon">
        <header className="flex h-[60px] flex-shrink-0 items-center justify-between border-b border-ink-900/8 bg-white/90 px-8 backdrop-blur dark:border-white/8 dark:bg-carbon-800/70">
          <h1 className="font-display text-[17px] font-bold text-ink-900 dark:text-white">{title}</h1>
          <div className="flex items-center gap-4">
            {right}
            <ThemeToggle />
          </div>
        </header>
        <main className="flex-1 overflow-auto p-8">{children}</main>
      </div>
    </div>
  );
}

PVBEOF

echo "Writing src/components/Badge.jsx..."
cat > "$APP/src/components/Badge.jsx" << 'PVBEOF'
/**
 * Statusindicator, gestyled als een systeem-LED in plaats van een gekleurd label —
 * past bij het servicedesk/ticket-karakter van de app.
 * Gebruik: <Badge status="gedownload" /> of <Badge>Actief</Badge>
 */
const MAP = {
  gedownload: { label: 'Gedownload', dot: 'bg-moss', text: 'text-ink-700 dark:text-white/75' },
  concept: { label: 'Concept', dot: 'bg-amber', text: 'text-ink-700 dark:text-white/75' },
  ingeleverd: { label: 'Ingeleverd', dot: 'bg-rust', text: 'text-ink-700 dark:text-white/75' },
  actief: { label: 'Actief', dot: 'bg-moss', text: 'text-ink-700 dark:text-white/75' },
  inactief: { label: 'Inactief', dot: 'bg-ink-500/50 dark:bg-white/25', text: 'text-ink-500 dark:text-white/45' },
};

export default function Badge({ status, children }) {
  const m = MAP[status] || { label: children, dot: 'bg-amber', text: 'text-ink-700 dark:text-white/75' };
  return (
    <span className={`inline-flex items-center gap-1.5 font-mono text-[11px] font-medium uppercase tracking-wide ${m.text}`}>
      <span className={`h-[7px] w-[7px] rounded-full ${m.dot}`} />
      {children || m.label}
    </span>
  );
}

PVBEOF

echo "Writing src/components/ThemeToggle.jsx..."
cat > "$APP/src/components/ThemeToggle.jsx" << 'PVBEOF'
import { Sun, Moon } from 'lucide-react';
import { useTheme } from '../context/ThemeContext';

/** Segmented Licht / Donker schakelaar. In de topbalk en op het inlogscherm. */
export default function ThemeToggle() {
  const { theme, setTheme } = useTheme();
  const base =
    'inline-flex items-center gap-1.5 rounded px-3 py-1.5 font-mono text-[11px] font-medium uppercase tracking-wide transition-all duration-150 ease-crisp';
  const active = 'bg-amber text-carbon-900';
  const idle = 'text-ink-500 dark:text-white/45 hover:text-ink-900 dark:hover:text-white';

  return (
    <div className="inline-flex rounded-md border border-ink-900/10 bg-black/[0.03] p-[3px] dark:border-white/10 dark:bg-white/[0.04]">
      <button
        type="button"
        onClick={() => setTheme('light')}
        className={`${base} ${theme === 'light' ? active : idle}`}
      >
        <Sun size={13} /> Licht
      </button>
      <button
        type="button"
        onClick={() => setTheme('dark')}
        className={`${base} ${theme === 'dark' ? active : idle}`}
      >
        <Moon size={13} /> Donker
      </button>
    </div>
  );
}

PVBEOF

echo "Writing src/pages/Login.jsx..."
cat > "$APP/src/pages/Login.jsx" << 'PVBEOF'
import { ShieldCheck, Lock, Terminal } from 'lucide-react';
import logo from '../assets/pvb-logo.png';
import ThemeToggle from '../components/ThemeToggle';

/**
 * Inlogscherm. Het linkerpaneel is altijd carbon (merk-hero), het rechterpaneel
 * wisselt licht/donker met het thema. De inlogknop start de OIDC-flow.
 */
export default function Login() {
  return (
    <div className="grid h-screen grid-cols-1 overflow-hidden font-sans md:grid-cols-[1.05fr_1fr]">
      {/* Hero — altijd donker, met een subtiel monospace "ticket"-motief */}
      <div className="relative hidden flex-col justify-between overflow-hidden bg-carbon-900 p-14 text-white md:flex">
        <div
          className="pointer-events-none absolute inset-0 opacity-[0.06]"
          style={{
            backgroundImage:
              'linear-gradient(rgba(226,150,47,0.6) 1px, transparent 1px), linear-gradient(90deg, rgba(226,150,47,0.6) 1px, transparent 1px)',
            backgroundSize: '34px 34px',
          }}
        />

        <div className="relative flex items-center gap-3">
          <img src={logo} alt="PVB" className="h-11 w-11 rounded bg-white object-contain" />
          <div>
            <div className="font-display text-base font-bold leading-tight">PVB Examenafspraken</div>
            <div className="text-xs text-white/45">Techniek College Rotterdam</div>
          </div>
        </div>

        <div className="relative">
          <p className="eyebrow">Proeve van bekwaamheid · B1-K1</p>
          <h2 className="mb-3.5 mt-2.5 font-display text-[34px] font-bold leading-tight tracking-tight">
            Van formulier naar
            <br />
            <span className="text-amber">examenklaar.</span>
          </h2>
          <p className="max-w-sm text-sm leading-relaxed text-white/65">
            Stel je examenafspraakformulier op voor drie werkprocessen en download
            het officiële Word-document.
          </p>
        </div>

        <div className="relative flex items-center gap-7 font-mono">
          <div>
            <div className="text-2xl font-semibold text-amber">3</div>
            <div className="text-[11px] uppercase tracking-[0.1em] text-white/45">werkprocessen</div>
          </div>
          <div>
            <div className="text-2xl font-semibold text-amber">~10<span className="text-sm">min</span></div>
            <div className="text-[11px] uppercase tracking-[0.1em] text-white/45">invultijd</div>
          </div>
          <Terminal size={22} strokeWidth={1.5} className="ml-auto text-white/25" />
        </div>
      </div>

      {/* Inlogpaneel — wisselt licht/donker */}
      <div className="flex flex-col bg-paper transition-colors duration-200 ease-crisp dark:bg-carbon">
        <div className="flex h-[60px] items-center justify-end px-7">
          <ThemeToggle />
        </div>
        <div className="flex flex-1 items-center justify-center px-12 pb-12">
          <div className="w-full max-w-sm text-center">
            <img src={logo} alt="PVB" className="mx-auto mb-3 h-[72px] w-[72px] rounded-lg object-contain" />
            <p className="eyebrow">Welkom</p>
            <h2 className="mb-2 mt-1.5 font-display text-[26px] font-bold tracking-tight text-ink-900 dark:text-white">
              Inloggen
            </h2>
            <p className="mb-7 text-sm leading-relaxed text-ink-700 dark:text-white/70">
              Gebruik je schoolaccount om verder te gaan.
            </p>

            {/* OIDC-login — verwijst naar Authentik */}
            <a
              href="/api/auth/login"
              className="flex w-full items-center justify-center gap-2 rounded bg-amber px-5 py-3.5 font-semibold text-carbon-900 transition-all duration-150 ease-crisp hover:bg-amber-600"
            >
              <ShieldCheck size={19} strokeWidth={1.75} /> Inloggen met schoolaccount
            </a>

            <div className="mt-5 flex items-center justify-center gap-2 font-mono text-[11px] text-ink-500 dark:text-white/45">
              <Lock size={13} strokeWidth={1.75} /> beveiligd via authentik sso
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

PVBEOF

echo "Writing src/pages/Dashboard.jsx..."
cat > "$APP/src/pages/Dashboard.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import {
  Plus, FilePlus2, FileCheck2, FilePenLine, CheckCheck, Download, Trash2,
  ArrowRight, Eye,
} from 'lucide-react';
import Layout from '../components/Layout';
import Badge from '../components/Badge';

const NieuwBtn = (
  <a
    href="/formulier/nieuw"
    className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 transition-all duration-150 ease-crisp hover:bg-amber-600"
  >
    <Plus size={17} strokeWidth={2} /> Nieuw formulier
  </a>
);

const cardCls =
  'rounded-lg border border-ink-900/8 bg-white p-5 transition-colors duration-200 ease-crisp dark:border-white/8 dark:bg-white/[0.03]';

export default function Dashboard() {
  const [formulieren, setFormulieren] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // GET /api/formulieren/mijn
    axios
      .get('/api/formulieren/mijn')
      .then((r) => setFormulieren(r.data))
      .catch(() => setFormulieren([]))
      .finally(() => setLoading(false));
  }, []);

  return (
    <Layout role="student" title="Mijn examenafspraken" right={NieuwBtn}>
      <p className="eyebrow mb-1">B1-K1 · ICT system engineer</p>

      {!loading && formulieren.length === 0 ? <EmptyState /> : <FormulierList items={formulieren} />}
    </Layout>
  );
}

/* ---------- Lege staat ---------- */
function EmptyState() {
  const steps = [
    { n: 1, t: 'Vul het formulier in', s: 'W1, W2 en W3.' },
    { n: 2, t: 'Download als Word', s: 'Officieel formulier.' },
    { n: 3, t: 'Onderteken & lever in', s: 'Via Canvas.' },
  ];
  return (
    <div className={`${cardCls} mx-auto mt-4 flex max-w-2xl flex-col items-center p-11 text-center`}>
      <span className="mb-4 flex h-14 w-14 items-center justify-center rounded-full border border-amber/40 text-amber">
        <FilePlus2 size={26} strokeWidth={1.75} />
      </span>
      <h2 className="mb-2 font-display text-xl font-bold text-ink-900 dark:text-white">Nog geen examenafspraken</h2>
      <p className="mb-5 max-w-md text-sm leading-relaxed text-ink-700 dark:text-white/65">
        Stel je eerste formulier op voor je Proeve van Bekwaamheid. Het duurt ongeveer 10 minuten.
      </p>
      <a
        href="/formulier/nieuw"
        className="inline-flex items-center gap-2 rounded bg-amber px-5 py-3 font-semibold text-carbon-900 transition-all hover:bg-amber-600"
      >
        <Plus size={19} strokeWidth={2} /> Maak je eerste formulier
      </a>
      <div className="mt-8 flex w-full gap-3 text-left">
        {steps.map((st) => (
          <div key={st.n} className="flex-1 rounded border border-ink-900/8 bg-paper p-4 dark:border-white/8 dark:bg-white/[0.02]">
            <span className="inline-flex h-6 w-6 items-center justify-center rounded border border-amber/40 font-mono text-[11px] font-semibold text-amber">
              {st.n}
            </span>
            <div className="mt-2.5 text-[13px] font-semibold text-ink-900 dark:text-white">{st.t}</div>
            <div className="mt-0.5 text-xs text-ink-500 dark:text-white/45">{st.s}</div>
          </div>
        ))}
      </div>
    </div>
  );
}

/* ---------- Gevulde lijst ---------- */
const ICONS = {
  gedownload: FileCheck2,
  concept: FilePenLine,
  ingeleverd: CheckCheck,
};

function FormulierList({ items }) {
  // Voorbeelddata zodat het scherm meteen rendert voordat de API is aangesloten.
  const rows = items.length
    ? items
    : [
        { id: 1, ticket: 'PVB-2026-0112', titel: 'Examenafspraak — periode 3', sub: 'Aangemaakt 28 jun 2026 · Beoordelaar: R. de Vries', status: 'gedownload' },
        { id: 2, ticket: 'PVB-2026-0141', titel: 'Examenafspraak — herkansing W2', sub: 'Aangemaakt 1 jul 2026 · Nog niet compleet', status: 'concept' },
        { id: 3, ticket: 'PVB-2026-0087', titel: 'Examenafspraak — periode 2', sub: 'Ingeleverd via Canvas · 12 mei 2026', status: 'ingeleverd' },
      ];

  return (
    <div className="mt-4 flex flex-col gap-3">
      {rows.map((f) => {
        const Icon = ICONS[f.status] || FilePenLine;
        return (
          <div key={f.id} className={`${cardCls} flex items-center gap-5`}>
            <span className="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded border border-ink-900/10 text-ink-700 dark:border-white/10 dark:text-white/70">
              <Icon size={21} strokeWidth={1.75} />
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex items-baseline gap-2">
                <span className="ticket-id">{f.ticket}</span>
              </div>
              <div className="truncate text-[15px] font-bold text-ink-900 dark:text-white">{f.titel}</div>
              <div className="mt-0.5 truncate text-[13px] text-ink-500 dark:text-white/45">{f.sub}</div>
            </div>
            <Badge status={f.status} />
            {f.status === 'concept' ? (
              <a href={`/formulier/${f.id}`} className="inline-flex items-center gap-1.5 rounded bg-amber px-3 py-1.5 text-sm font-semibold text-carbon-900 hover:bg-amber-600">
                <ArrowRight size={14} /> Verder
              </a>
            ) : (
              // GET /api/formulieren/:id/export/docx
              <a href={`/api/formulieren/${f.id}/export/docx`} className="inline-flex items-center gap-1.5 rounded border border-ink-900/15 px-3 py-1.5 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber dark:border-white/15 dark:text-white">
                <Download size={14} /> Word
              </a>
            )}
            <button className="text-ink-500 hover:text-ink-900 dark:text-white/40 dark:hover:text-white" aria-label={f.status === 'concept' ? 'Verwijderen' : 'Bekijken'}>
              {f.status === 'concept' ? <Trash2 size={16} /> : <Eye size={16} />}
            </button>
          </div>
        );
      })}
    </div>
  );
}

PVBEOF

echo "Writing src/pages/DocentDashboard.jsx..."
cat > "$APP/src/pages/DocentDashboard.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Search, Eye } from 'lucide-react';
import Layout from '../components/Layout';
import Badge from '../components/Badge';

const cardCls =
  'rounded-lg border border-ink-900/8 bg-white transition-colors duration-200 ease-crisp dark:border-white/8 dark:bg-white/[0.03]';

export default function DocentDashboard() {
  const [rows, setRows] = useState([]);

  useEffect(() => {
    // GET /api/formulieren/alle
    axios.get('/api/formulieren/alle').then((r) => setRows(r.data)).catch(() => setRows([]));
  }, []);

  const data = rows.length
    ? rows
    : [
        { id: 1, naam: 'Bes Ternava', initials: 'BT', klas: 'SE4A', datum: '28 jun 2026', status: 'gedownload' },
        { id: 2, naam: 'Lisa Koster', initials: 'LK', klas: 'SE4A', datum: '27 jun 2026', status: 'concept' },
        { id: 3, naam: 'Deen Ali', initials: 'DA', klas: 'SE4B', datum: '26 jun 2026', status: 'ingeleverd' },
        { id: 4, naam: 'Mees Vermeer', initials: 'MV', klas: 'SE4B', datum: '24 jun 2026', status: 'gedownload' },
      ];

  const totaal = data.length;
  const gedownload = data.filter((d) => d.status === 'gedownload').length;
  const concept = data.filter((d) => d.status === 'concept').length;

  const search = (
    <div className="flex min-w-[280px] items-center gap-2.5 rounded border border-ink-900/10 bg-paper px-3.5 py-2 dark:border-white/10 dark:bg-white/[0.03]">
      <Search size={15} className="text-ink-500 dark:text-white/40" />
      <input placeholder="Zoek student of klas…" className="w-full bg-transparent text-sm text-ink-900 placeholder:text-ink-500 focus:outline-none dark:text-white dark:placeholder:text-white/40" />
    </div>
  );

  return (
    <Layout role="docent" title="Alle examenafspraken" right={search}>
      {/* Statistieken */}
      <div className="mb-5 flex gap-3">
        <Stat label="Totaal" value={totaal} />
        <Stat label="Gedownload" value={gedownload} accent="text-moss" />
        <Stat label="Concept" value={concept} accent="text-amber" />
      </div>

      {/* Tabel */}
      <div className={`${cardCls} overflow-hidden`}>
        <table className="w-full border-collapse text-[13.5px]">
          <thead>
            <tr>
              {['Student', 'Klas', 'Datum', 'Status', ''].map((h, i) => (
                <th key={i} className="border-b border-ink-900/8 px-5 py-3 text-left font-mono text-[10.5px] font-semibold uppercase tracking-[0.08em] text-ink-500 dark:border-white/8 dark:text-white/40">
                  {h}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {data.map((r) => (
              <tr key={r.id} className="border-t border-ink-900/6 dark:border-white/6">
                <td className="px-5 py-3.5">
                  <div className="flex items-center gap-2.5">
                    <span className="flex h-[30px] w-[30px] items-center justify-center rounded-full border border-ink-900/10 font-mono text-[11px] font-semibold text-ink-700 dark:border-white/15 dark:text-white/70">
                      {r.initials}
                    </span>
                    <span className="font-semibold text-ink-900 dark:text-white">{r.naam}</span>
                  </div>
                </td>
                <td className="px-5 py-3.5 text-ink-700 dark:text-white/65">{r.klas}</td>
                <td className="px-5 py-3.5 text-ink-700 dark:text-white/65">{r.datum}</td>
                <td className="px-5 py-3.5"><Badge status={r.status} /></td>
                <td className="px-5 py-3.5 text-right">
                  <a href={`/docent/formulier/${r.id}`} className="inline-flex items-center gap-1.5 rounded border border-ink-900/12 px-3 py-1.5 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber dark:border-white/15 dark:text-white">
                    <Eye size={14} /> Bekijk
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </Layout>
  );
}

function Stat({ label, value, accent = 'text-ink-900 dark:text-white' }) {
  return (
    <div className={`${cardCls} flex-1 p-4`}>
      <div className="font-mono text-[10.5px] uppercase tracking-[0.1em] text-ink-500 dark:text-white/40">{label}</div>
      <div className={`mt-1 font-display text-[28px] font-bold ${accent}`}>{value}</div>
    </div>
  );
}

PVBEOF

echo "Writing src/pages/OpdrachtenBeheer.jsx..."
cat > "$APP/src/pages/OpdrachtenBeheer.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Plus, Ticket, KeyRound, Wrench, Pencil, Trash2 } from 'lucide-react';
import Layout from '../components/Layout';
import Badge from '../components/Badge';

const cardCls =
  'rounded-lg border border-ink-900/8 bg-white p-4 transition-colors duration-200 ease-crisp dark:border-white/8 dark:bg-white/[0.03]';

const WERKPROCESSEN = [
  { key: 'W1', label: 'W1 · Handelt meldingen af' },
  { key: 'W2', label: 'W2 · Instrueert gebruikers' },
  { key: 'W3', label: 'W3 · Beheert devices' },
];

const ICONS = [Ticket, KeyRound, Wrench];

export default function OpdrachtenBeheer() {
  const [tab, setTab] = useState('W1');
  const [opdrachten, setOpdrachten] = useState([]);

  useEffect(() => {
    // GET /api/opdrachten/beheer (docent: incl. inactieve)
    axios.get('/api/opdrachten/beheer').then((r) => setOpdrachten(r.data)).catch(() => setOpdrachten([]));
  }, []);

  const sample = [
    { titel: 'Storingsmeldingen afhandelen', omschrijving: 'Neem meldingen aan, registreer en handel ze af binnen de SLA. · 2 subvragen', is_actief: true },
    { titel: 'Wachtwoordreset & accountbeheer', omschrijving: 'Verwerk toegangsaanvragen, reset accounts en documenteer de handeling. · 3 subvragen', is_actief: true },
    { titel: 'Hardwarestoring diagnosticeren', omschrijving: 'Onderzoek een defect device en voer of plan de reparatie. · 2 subvragen', is_actief: false },
  ];
  const rows = opdrachten.length ? opdrachten.filter((o) => o.werkproces === tab) : sample;

  const NieuwBtn = (
    <button className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600">
      <Plus size={17} strokeWidth={2} /> Nieuwe opdracht
    </button>
  );

  return (
    <Layout role="docent" title="Opdrachtenbank" right={NieuwBtn}>
      {/* Tabs per werkproces */}
      <div className="mb-5 flex gap-2 border-b border-ink-900/8 dark:border-white/8">
        {WERKPROCESSEN.map((w) => (
          <button
            key={w.key}
            onClick={() => setTab(w.key)}
            className={`px-4 py-2.5 text-sm transition-colors ${
              tab === w.key
                ? 'border-b-2 border-amber font-semibold text-ink-900 dark:text-white'
                : 'font-medium text-ink-500 dark:text-white/50'
            }`}
          >
            {w.label} <span className="font-mono text-ink-500 dark:text-white/40">3</span>
          </button>
        ))}
      </div>

      <div className="flex flex-col gap-3">
        {rows.map((o, i) => {
          const Icon = ICONS[i % ICONS.length];
          return (
            <div key={i} className={`${cardCls} flex items-center gap-4 ${!o.is_actief ? 'opacity-60' : ''}`}>
              <span className="flex h-9 w-9 items-center justify-center rounded border border-ink-900/10 text-ink-700 dark:border-white/10 dark:text-white/70">
                <Icon size={18} strokeWidth={1.75} />
              </span>
              <div className="flex-1">
                <div className="text-[14.5px] font-bold text-ink-900 dark:text-white">{o.titel}</div>
                <div className="mt-0.5 text-[12.5px] text-ink-500 dark:text-white/45">{o.omschrijving}</div>
              </div>
              <Badge status={o.is_actief ? 'actief' : 'inactief'} />
              <button className="text-ink-500 hover:text-ink-900 dark:text-white/45 dark:hover:text-white" aria-label="Bewerken"><Pencil size={15} /></button>
              <button className="text-ink-500 hover:text-ink-900 dark:text-white/45 dark:hover:text-white" aria-label="Verwijderen"><Trash2 size={15} /></button>
            </div>
          );
        })}
      </div>
    </Layout>
  );
}

PVBEOF

echo "Writing src/pages/FormulierInvullen.jsx..."
cat > "$APP/src/pages/FormulierInvullen.jsx" << 'PVBEOF'
import { useState } from 'react';
import { CheckCircle2, ArrowLeft, ArrowRight } from 'lucide-react';
import logo from '../assets/pvb-logo.png';
import ThemeToggle from '../components/ThemeToggle';

/**
 * 5-staps wizard. Dit scherm gebruikt een eigen sidebar (de stap-tracker) in
 * plaats van de standaard Layout-navigatie, maar behoudt dezelfde carbon-sidebar /
 * wisselend-werkvlak structuur. Stap 2 (opdracht kiezen) wordt getoond; de andere
 * stappen sluit je op dezelfde manier aan.
 *
 * Werkprocessen: B1-K1-W1 (meldingen), W2 (instrueert), W3 (devices).
 */
const STEPS = [
  { n: 1, label: 'Gegevens' },
  { n: 2, label: 'Werkproces 1' },
  { n: 3, label: 'Werkproces 2' },
  { n: 4, label: 'Werkproces 3' },
  { n: 5, label: 'Controleren' },
];

export default function FormulierInvullen() {
  const [step, setStep] = useState(2);
  const [gekozen, setGekozen] = useState(0);

  // GET /api/opdrachten → opdrachten voor het huidige werkproces
  const opdrachten = [
    { titel: 'Storingsmeldingen afhandelen', body: 'Neem meldingen aan, registreer en prioriteer ze en handel ze af binnen de SLA.' },
    { titel: 'Wachtwoordreset & accountbeheer', body: 'Verwerk toegangsaanvragen, reset accounts en documenteer de handeling.' },
    { titel: 'Hardwarestoring diagnosticeren', body: 'Onderzoek een defect device, bepaal de oorzaak en voer de reparatie uit.' },
  ];

  const inputCls =
    'w-full rounded border px-3.5 py-2.5 text-sm text-ink-900 placeholder:text-ink-500 border-ink-900/15 bg-white dark:text-white dark:placeholder:text-white/35 dark:border-white/15 dark:bg-white/[0.05]';

  return (
    <div className="grid h-screen grid-cols-[236px_1fr] overflow-hidden font-sans">
      {/* Stap-tracker sidebar — altijd carbon, met geperforeerde rand (ticket-motief) */}
      <aside className="relative flex flex-col bg-carbon px-3.5 py-4">
        <div className="pointer-events-none absolute right-0 top-0 h-full w-px bg-perforation" />

        <div className="flex items-center gap-3 px-2 pb-5 pt-1.5">
          <img src={logo} alt="PVB" className="h-9 w-9 rounded bg-white object-contain" />
          <div>
            <div className="font-display text-sm font-bold leading-none text-white">PVB</div>
            <div className="mt-1 font-mono text-[10px] tracking-wide text-white/40">Examenafspraken</div>
          </div>
        </div>
        <div className="px-2.5 py-1.5 font-mono text-[10px] uppercase tracking-[0.14em] text-white/35">Nieuw formulier</div>

        <nav className="flex flex-col gap-0.5">
          {STEPS.map((s) => {
            const done = s.n < step;
            const active = s.n === step;
            return (
              <div
                key={s.n}
                className={`flex items-center gap-2.5 rounded px-2.5 py-2 text-[12.5px] ${
                  active ? 'bg-amber/15 font-semibold text-amber' : done ? 'font-semibold text-amber/80' : 'text-white/45'
                }`}
              >
                {done ? (
                  <CheckCircle2 size={16} />
                ) : (
                  <span className={`flex h-4 w-4 items-center justify-center rounded-full font-mono text-[10px] font-bold ${active ? 'bg-amber text-carbon-900' : 'border border-white/25'}`}>
                    {s.n}
                  </span>
                )}
                {s.label}
              </div>
            );
          })}
        </nav>
      </aside>

      {/* Werkvlak */}
      <div className="flex flex-col overflow-hidden bg-paper transition-colors duration-200 ease-crisp dark:bg-carbon">
        <header className="flex h-[60px] flex-shrink-0 items-center justify-between border-b border-ink-900/8 bg-white/90 px-8 backdrop-blur dark:border-white/8 dark:bg-carbon-800/70">
          <div className="flex items-center gap-3">
            <span className="ticket-id">Stap {step} / 5</span>
            <span className="font-display text-[17px] font-bold text-ink-900 dark:text-white">Werkproces 1 — opdracht kiezen</span>
          </div>
          <ThemeToggle />
        </header>

        <main className="flex-1 overflow-auto p-8">
          <p className="eyebrow">B1-K1-W1 · Handelt meldingen af</p>
          <p className="mb-4 mt-2 text-sm text-ink-700 dark:text-white/65">
            Selecteer de opdracht uit de opdrachtenbank die je uitvoert voor dit werkproces.
          </p>

          <div className="flex gap-3.5">
            {opdrachten.map((o, i) => {
              const sel = i === gekozen;
              return (
                <button
                  key={i}
                  onClick={() => setGekozen(i)}
                  className={`flex-1 rounded-lg p-[18px] text-left transition-all duration-150 ease-crisp ${
                    sel
                      ? 'border-2 border-amber bg-amber/8'
                      : 'border border-ink-900/10 bg-white dark:border-white/10 dark:bg-white/[0.03]'
                  }`}
                >
                  <div className="flex items-center justify-between">
                    {sel ? (
                      <span className="font-mono text-[10px] font-semibold uppercase tracking-wide text-amber">Gekozen</span>
                    ) : (
                      <span className="font-mono text-[10px] font-semibold uppercase tracking-wide text-ink-500 dark:text-white/40">Opdracht {i + 1}</span>
                    )}
                    {sel && <CheckCircle2 size={19} className="text-amber" />}
                  </div>
                  <div className="mt-3 text-[15px] font-bold text-ink-900 dark:text-white">{o.titel}</div>
                  <div className="mt-1.5 text-[12.5px] leading-relaxed text-ink-500 dark:text-white/45">{o.body}</div>
                </button>
              );
            })}
          </div>

          <div className="mt-5 flex gap-4">
            <div className="flex-[1.6]">
              <label className="mb-1.5 block text-xs font-semibold text-ink-900 dark:text-white">Aanvullende afspraken</label>
              <textarea rows={2} className={`${inputCls} resize-none`} placeholder="Bijv. specifieke context binnen je BPV-bedrijf…" />
            </div>
            <div className="flex-1">
              <label className="mb-1.5 block text-xs font-semibold text-ink-900 dark:text-white">Periode</label>
              <input className={inputCls} placeholder="wk 12 – wk 18" />
            </div>
          </div>
        </main>

        <footer className="flex flex-shrink-0 justify-between border-t border-ink-900/8 bg-white/90 px-8 py-4 dark:border-white/8 dark:bg-carbon-800/70">
          <button
            onClick={() => setStep((s) => Math.max(1, s - 1))}
            className="inline-flex items-center gap-2 rounded border border-ink-900/12 px-4 py-2 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber dark:border-white/15 dark:text-white"
          >
            <ArrowLeft size={17} /> Vorige
          </button>
          <button
            onClick={() => setStep((s) => Math.min(5, s + 1))}
            className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600"
          >
            Volgende: Werkproces 2 <ArrowRight size={17} />
          </button>
        </footer>
      </div>
    </div>
  );
}

PVBEOF

echo "Writing package.json..."
cat > "$APP/package.json" << 'PVBEOF'
{
  "name": "pvb-frontend",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.21.0",
    "axios": "^1.6.2",
    "lucide-react": "^0.400.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.1",
    "vite": "^5.0.10",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32"
  }
}

PVBEOF

echo "Removing old Navbar.jsx (replaced by Layout.jsx)..."
rm -f "$APP/src/components/Navbar.jsx"

if [ ! -f "$APP/src/assets/pvb-logo.png" ]; then
  echo "WAARSCHUWING: $APP/src/assets/pvb-logo.png ontbreekt! Layout/Login/FormulierInvullen verwachten dit bestand."
fi

echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build frontend && docker compose up -d frontend"
