#!/bin/bash
set -e
FRONT=/opt/bvp-app/frontend
BACK=/opt/bvp-app/backend
echo "Backing up..."
cp -r "$FRONT" "$FRONT.backup-fix-$(date +%F-%H%M)"
cp -r "$BACK" "$BACK.backup-fix-$(date +%F-%H%M)"

echo "Writing src/components/Badge.jsx..."
cat > "$FRONT/src/components/Badge.jsx" << 'PVBEOF'
/**
 * Statusindicator, gestyled als een systeem-LED. Statuswaarden komen direct uit
 * de database-check-constraint op formulieren.status: concept | ingediend |
 * goedgekeurd | afgekeurd. Ook bruikbaar voor opdrachten.is_actief (actief/inactief).
 */
const MAP = {
  concept: { label: 'Concept', dot: 'bg-amber' },
  ingediend: { label: 'Ingediend', dot: 'bg-ink-500 dark:bg-white/40' },
  goedgekeurd: { label: 'Goedgekeurd', dot: 'bg-moss' },
  afgekeurd: { label: 'Afgekeurd', dot: 'bg-rust' },
  actief: { label: 'Actief', dot: 'bg-moss' },
  inactief: { label: 'Inactief', dot: 'bg-ink-500/50 dark:bg-white/25' },
};

export default function Badge({ status, children }) {
  const m = MAP[status] || { label: children || status, dot: 'bg-amber' };
  return (
    <span className="inline-flex items-center gap-1.5 font-mono text-[11px] font-medium uppercase tracking-wide text-ink-700 dark:text-white/75">
      <span className={`h-[7px] w-[7px] rounded-full ${m.dot}`} />
      {children || m.label}
    </span>
  );
}

PVBEOF

echo "Writing src/pages/Dashboard.jsx..."
cat > "$FRONT/src/pages/Dashboard.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Plus, FilePlus2, FileCheck2, FilePenLine, CheckCheck, XCircle, Download, Send } from 'lucide-react';
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

function formatDate(d) {
  if (!d) return '';
  return new Date(d).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', year: 'numeric' });
}

export default function Dashboard() {
  const [formulieren, setFormulieren] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);

  function laden() {
    setLoading(true);
    // GET /api/formulieren/mijn
    axios
      .get('/api/formulieren/mijn')
      .then((r) => setFormulieren(r.data))
      .catch(() => setFormulieren([]))
      .finally(() => setLoading(false));
  }

  useEffect(laden, []);

  async function dienIn(id) {
    setBusyId(id);
    try {
      // PUT /api/formulieren/:id/indienen
      await axios.put(`/api/formulieren/${id}/indienen`);
      laden();
    } catch {
      alert('Indienen is niet gelukt. Probeer het opnieuw.');
    } finally {
      setBusyId(null);
    }
  }

  return (
    <Layout role="student" title="Mijn examenafspraken" right={NieuwBtn}>
      <p className="eyebrow mb-1">B1-K1 · ICT system engineer</p>

      {!loading && formulieren.length === 0 ? (
        <EmptyState />
      ) : (
        <FormulierList items={formulieren} busyId={busyId} onIndienen={dienIn} />
      )}
    </Layout>
  );
}

/* ---------- Lege staat ---------- */
function EmptyState() {
  const steps = [
    { n: 1, t: 'Vul het formulier in', s: 'W1, W2 en W3.' },
    { n: 2, t: 'Dien het formulier in', s: 'Beoordelaar krijgt het te zien.' },
    { n: 3, t: 'Download als Word', s: 'Zodra het is beoordeeld.' },
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
  concept: FilePenLine,
  ingediend: CheckCheck,
  goedgekeurd: FileCheck2,
  afgekeurd: XCircle,
};

function FormulierList({ items, busyId, onIndienen }) {
  return (
    <div className="mt-4 flex flex-col gap-3">
      {items.map((f) => {
        const Icon = ICONS[f.status] || FilePenLine;
        const werkprocessenCompleet = Array.isArray(f.werkprocessen) ? f.werkprocessen.length : 0;
        return (
          <div key={f.id} className={`${cardCls} flex items-center gap-5`}>
            <span className="flex h-11 w-11 flex-shrink-0 items-center justify-center rounded border border-ink-900/10 text-ink-700 dark:border-white/10 dark:text-white/70">
              <Icon size={21} strokeWidth={1.75} />
            </span>
            <div className="min-w-0 flex-1">
              <div className="flex items-baseline gap-2">
                <span className="ticket-id">PVB-{f.id.slice(0, 8).toUpperCase()}</span>
              </div>
              <div className="truncate text-[15px] font-bold text-ink-900 dark:text-white">
                Examenafspraak — {f.klas} · {formatDate(f.datum)}
              </div>
              <div className="mt-0.5 truncate text-[13px] text-ink-500 dark:text-white/45">
                Studentnr. {f.studentnummer} · Beoordelaar: {f.beoordelaar_1}
                {werkprocessenCompleet < 3 ? ' · Let op: niet alle werkprocessen compleet' : ''}
              </div>
            </div>
            <Badge status={f.status} />
            {f.status === 'concept' ? (
              <button
                onClick={() => onIndienen(f.id)}
                disabled={busyId === f.id}
                className="inline-flex items-center gap-1.5 rounded bg-amber px-3 py-1.5 text-sm font-semibold text-carbon-900 hover:bg-amber-600 disabled:opacity-50"
              >
                <Send size={14} /> {busyId === f.id ? 'Bezig…' : 'Dien in'}
              </button>
            ) : (
              // GET /api/formulieren/:id/export/docx
              <a
                href={`/api/formulieren/${f.id}/export/docx`}
                className="inline-flex items-center gap-1.5 rounded border border-ink-900/15 px-3 py-1.5 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber dark:border-white/15 dark:text-white"
              >
                <Download size={14} /> Word
              </a>
            )}
          </div>
        );
      })}
    </div>
  );
}

PVBEOF

echo "Writing src/pages/FormulierInvullen.jsx..."
cat > "$FRONT/src/pages/FormulierInvullen.jsx" << 'PVBEOF'
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle2, ArrowLeft, ArrowRight, Loader2 } from 'lucide-react';
import logo from '../assets/pvb-logo.png';
import ThemeToggle from '../components/ThemeToggle';

/**
 * 5-staps wizard die één keer alles verzamelt en dan in één POST wegschrijft
 * (de backend heeft geen route om een concept tussentijds te bewaren/hervatten —
 * /api/formulieren verwacht meteen alle drie werkprocessen erbij).
 *
 * Werkprocessen: B1-K1-W1 (meldingen), W2 (instrueert), W3 (devices).
 */
const WP_CODES = ['B1-K1-W1', 'B1-K1-W2', 'B1-K1-W3'];
const WP_LABELS = {
  'B1-K1-W1': 'Werkproces 1 · Handelt meldingen af',
  'B1-K1-W2': 'Werkproces 2 · Instrueert gebruikers',
  'B1-K1-W3': 'Werkproces 3 · Beheert devices',
};
const STEPS = [
  { n: 1, label: 'Gegevens' },
  { n: 2, label: 'Werkproces 1' },
  { n: 3, label: 'Werkproces 2' },
  { n: 4, label: 'Werkproces 3' },
  { n: 5, label: 'Controleren' },
];

const emptyWp = () => ({
  opdracht_id: '',
  aanvullende_afspraken: '',
  periode_start: '',
  periode_einde: '',
  beoordelmoment: '',
  antwoorden: {}, // { [subvraag_id]: tekst }
});

const inputCls =
  'w-full rounded border px-3.5 py-2.5 text-sm text-ink-900 placeholder:text-ink-500 border-ink-900/15 bg-white dark:text-white dark:placeholder:text-white/35 dark:border-white/15 dark:bg-white/[0.05]';
const labelCls = 'mb-1.5 block text-xs font-semibold text-ink-900 dark:text-white';

export default function FormulierInvullen() {
  const navigate = useNavigate();
  const [step, setStep] = useState(1);
  const [opdrachten, setOpdrachten] = useState([]);
  const [ladenOpdrachten, setLadenOpdrachten] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [fout, setFout] = useState('');

  const [gegevens, setGegevens] = useState({
    datum: '',
    studentnummer: '',
    klas: '',
    beoordelaar_1: '',
    beoordelaar_2: '',
  });
  const [wp, setWp] = useState({
    'B1-K1-W1': emptyWp(),
    'B1-K1-W2': emptyWp(),
    'B1-K1-W3': emptyWp(),
  });

  useEffect(() => {
    // GET /api/opdrachten
    axios
      .get('/api/opdrachten')
      .then((r) => setOpdrachten(r.data))
      .catch(() => setOpdrachten([]))
      .finally(() => setLadenOpdrachten(false));
  }, []);

  const opdrachtenPerWp = useMemo(() => {
    const map = {};
    WP_CODES.forEach((code) => {
      map[code] = opdrachten.filter((o) => o.werkproces === code);
    });
    return map;
  }, [opdrachten]);

  function setGegeven(veld, waarde) {
    setGegevens((g) => ({ ...g, [veld]: waarde }));
  }

  function setWpVeld(code, veld, waarde) {
    setWp((prev) => ({ ...prev, [code]: { ...prev[code], [veld]: waarde } }));
  }

  function kiesOpdracht(code, opdrachtId) {
    setWp((prev) => ({ ...prev, [code]: { ...emptyWp(), opdracht_id: opdrachtId } }));
  }

  function setAntwoord(code, subvraagId, tekst) {
    setWp((prev) => ({
      ...prev,
      [code]: { ...prev[code], antwoorden: { ...prev[code].antwoorden, [subvraagId]: tekst } },
    }));
  }

  function stapGeldig(n) {
    if (n === 1) {
      return gegevens.datum && gegevens.studentnummer && gegevens.klas && gegevens.beoordelaar_1;
    }
    if (n >= 2 && n <= 4) {
      const code = WP_CODES[n - 2];
      return !!wp[code].opdracht_id;
    }
    return true;
  }

  async function versturen() {
    setSubmitting(true);
    setFout('');
    const payload = {
      ...gegevens,
      werkprocessen: WP_CODES.map((code) => {
        const w = wp[code];
        return {
          werkproces: code,
          opdracht_id: w.opdracht_id,
          aanvullende_afspraken: w.aanvullende_afspraken,
          periode_start: w.periode_start || null,
          periode_einde: w.periode_einde || null,
          beoordelmoment: w.beoordelmoment,
          subvraag_antwoorden: Object.entries(w.antwoorden)
            .filter(([, tekst]) => tekst && tekst.trim())
            .map(([subvraag_id, antwoord]) => ({ subvraag_id, antwoord })),
        };
      }),
    };
    try {
      // POST /api/formulieren
      await axios.post('/api/formulieren', payload);
      navigate('/dashboard');
    } catch (err) {
      setFout('Opslaan is niet gelukt. Controleer of alle verplichte velden zijn ingevuld en probeer het opnieuw.');
    } finally {
      setSubmitting(false);
    }
  }

  const huidigeTitel = step === 1 ? 'Gegevens' : step === 5 ? 'Controleren' : WP_LABELS[WP_CODES[step - 2]];

  return (
    <div className="grid h-screen grid-cols-[236px_1fr] overflow-hidden font-sans">
      {/* Stap-tracker sidebar */}
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
            const bereikbaar = s.n <= step || [1, 2, 3, 4].slice(0, s.n - 1).every(stapGeldig);
            return (
              <button
                key={s.n}
                type="button"
                onClick={() => bereikbaar && setStep(s.n)}
                disabled={!bereikbaar}
                className={`flex items-center gap-2.5 rounded px-2.5 py-2 text-left text-[12.5px] disabled:cursor-not-allowed ${
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
              </button>
            );
          })}
        </nav>
      </aside>

      {/* Werkvlak */}
      <div className="flex flex-col overflow-hidden bg-paper transition-colors duration-200 ease-crisp dark:bg-carbon">
        <header className="flex h-[60px] flex-shrink-0 items-center justify-between border-b border-ink-900/8 bg-white/90 px-8 backdrop-blur dark:border-white/8 dark:bg-carbon-800/70">
          <div className="flex items-center gap-3">
            <span className="ticket-id">Stap {step} / 5</span>
            <span className="font-display text-[17px] font-bold text-ink-900 dark:text-white">{huidigeTitel}</span>
          </div>
          <ThemeToggle />
        </header>

        <main className="flex-1 overflow-auto p-8">
          {step === 1 && <StapGegevens gegevens={gegevens} setGegeven={setGegeven} />}
          {step >= 2 && step <= 4 && (
            <StapWerkproces
              code={WP_CODES[step - 2]}
              opdrachten={opdrachtenPerWp[WP_CODES[step - 2]] || []}
              laden={ladenOpdrachten}
              waarde={wp[WP_CODES[step - 2]]}
              onKies={(id) => kiesOpdracht(WP_CODES[step - 2], id)}
              onVeld={(veld, val) => setWpVeld(WP_CODES[step - 2], veld, val)}
              onAntwoord={(subvraagId, tekst) => setAntwoord(WP_CODES[step - 2], subvraagId, tekst)}
            />
          )}
          {step === 5 && (
            <StapControleren gegevens={gegevens} wp={wp} opdrachten={opdrachten} fout={fout} />
          )}
        </main>

        <footer className="flex flex-shrink-0 justify-between border-t border-ink-900/8 bg-white/90 px-8 py-4 dark:border-white/8 dark:bg-carbon-800/70">
          <button
            onClick={() => setStep((s) => Math.max(1, s - 1))}
            disabled={step === 1}
            className="inline-flex items-center gap-2 rounded border border-ink-900/12 px-4 py-2 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber disabled:opacity-40 dark:border-white/15 dark:text-white"
          >
            <ArrowLeft size={17} /> Vorige
          </button>
          {step < 5 ? (
            <button
              onClick={() => setStep((s) => Math.min(5, s + 1))}
              disabled={!stapGeldig(step)}
              className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600 disabled:opacity-40"
            >
              Volgende <ArrowRight size={17} />
            </button>
          ) : (
            <button
              onClick={versturen}
              disabled={submitting}
              className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600 disabled:opacity-60"
            >
              {submitting ? <Loader2 size={17} className="animate-spin" /> : <CheckCircle2 size={17} />}
              {submitting ? 'Bezig met opslaan…' : 'Formulier opslaan'}
            </button>
          )}
        </footer>
      </div>
    </div>
  );
}

/* ---------- Stap 1: gegevens ---------- */
function StapGegevens({ gegevens, setGegeven }) {
  return (
    <div className="max-w-2xl">
      <p className="eyebrow">Formuliergegevens</p>
      <p className="mb-5 mt-2 text-sm text-ink-700 dark:text-white/65">
        Deze gegevens komen bovenaan je examenafsprakenformulier te staan.
      </p>
      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className={labelCls}>Datum</label>
          <input type="date" className={inputCls} value={gegevens.datum} onChange={(e) => setGegeven('datum', e.target.value)} />
        </div>
        <div>
          <label className={labelCls}>Studentnummer</label>
          <input className={inputCls} placeholder="Bijv. 500123456" value={gegevens.studentnummer} onChange={(e) => setGegeven('studentnummer', e.target.value)} />
        </div>
        <div>
          <label className={labelCls}>Klas</label>
          <input className={inputCls} placeholder="Bijv. SE4A" value={gegevens.klas} onChange={(e) => setGegeven('klas', e.target.value)} />
        </div>
        <div />
        <div>
          <label className={labelCls}>Beoordelaar 1</label>
          <input className={inputCls} placeholder="Naam docent-beoordelaar" value={gegevens.beoordelaar_1} onChange={(e) => setGegeven('beoordelaar_1', e.target.value)} />
        </div>
        <div>
          <label className={labelCls}>Beoordelaar 2 (optioneel)</label>
          <input className={inputCls} placeholder="Naam tweede beoordelaar" value={gegevens.beoordelaar_2} onChange={(e) => setGegeven('beoordelaar_2', e.target.value)} />
        </div>
      </div>
    </div>
  );
}

/* ---------- Stap 2-4: werkproces ---------- */
function StapWerkproces({ code, opdrachten, laden, waarde, onKies, onVeld, onAntwoord }) {
  const gekozenOpdracht = opdrachten.find((o) => o.id === waarde.opdracht_id);

  return (
    <div>
      <p className="eyebrow">{code} · {WP_LABELS[code]}</p>
      <p className="mb-4 mt-2 text-sm text-ink-700 dark:text-white/65">
        Selecteer de opdracht uit de opdrachtenbank die je uitvoert voor dit werkproces.
      </p>

      {laden ? (
        <p className="text-sm text-ink-500 dark:text-white/45">Opdrachten laden…</p>
      ) : opdrachten.length === 0 ? (
        <p className="text-sm text-ink-500 dark:text-white/45">Geen opdrachten gevonden voor dit werkproces. Vraag je docent om er een toe te voegen.</p>
      ) : (
        <div className="flex gap-3.5">
          {opdrachten.map((o) => {
            const sel = o.id === waarde.opdracht_id;
            return (
              <button
                key={o.id}
                onClick={() => onKies(o.id)}
                className={`flex-1 rounded-lg p-[18px] text-left transition-all duration-150 ease-crisp ${
                  sel ? 'border-2 border-amber bg-amber/8' : 'border border-ink-900/10 bg-white dark:border-white/10 dark:bg-white/[0.03]'
                }`}
              >
                <div className="flex items-center justify-between">
                  <span className={`font-mono text-[10px] font-semibold uppercase tracking-wide ${sel ? 'text-amber' : 'text-ink-500 dark:text-white/40'}`}>
                    {sel ? 'Gekozen' : 'Opdracht'}
                  </span>
                  {sel && <CheckCircle2 size={19} className="text-amber" />}
                </div>
                <div className="mt-3 text-[15px] font-bold text-ink-900 dark:text-white">{o.titel}</div>
                <div className="mt-1.5 text-[12.5px] leading-relaxed text-ink-500 dark:text-white/45">{o.omschrijving}</div>
              </button>
            );
          })}
        </div>
      )}

      {gekozenOpdracht?.subvragen?.length > 0 && (
        <div className="mt-5 flex flex-col gap-3">
          <p className="text-xs font-semibold uppercase tracking-wide text-ink-500 dark:text-white/45">Subvragen</p>
          {gekozenOpdracht.subvragen.map((sv) => (
            <div key={sv.id}>
              <label className={labelCls}>{sv.vraag}</label>
              <textarea
                rows={2}
                className={`${inputCls} resize-none`}
                value={waarde.antwoorden[sv.id] || ''}
                onChange={(e) => onAntwoord(sv.id, e.target.value)}
              />
            </div>
          ))}
        </div>
      )}

      <div className="mt-5 flex gap-4">
        <div className="flex-[1.6]">
          <label className={labelCls}>Aanvullende afspraken</label>
          <textarea
            rows={2}
            className={`${inputCls} resize-none`}
            placeholder="Bijv. specifieke context binnen je BPV-bedrijf…"
            value={waarde.aanvullende_afspraken}
            onChange={(e) => onVeld('aanvullende_afspraken', e.target.value)}
          />
        </div>
        <div className="flex-1">
          <label className={labelCls}>Periode start</label>
          <input type="date" className={inputCls} value={waarde.periode_start} onChange={(e) => onVeld('periode_start', e.target.value)} />
        </div>
        <div className="flex-1">
          <label className={labelCls}>Periode einde</label>
          <input type="date" className={inputCls} value={waarde.periode_einde} onChange={(e) => onVeld('periode_einde', e.target.value)} />
        </div>
      </div>
      <div className="mt-4 max-w-sm">
        <label className={labelCls}>Beoordelmoment</label>
        <input className={inputCls} placeholder="Bijv. wk 15, tijdens werkplekbezoek" value={waarde.beoordelmoment} onChange={(e) => onVeld('beoordelmoment', e.target.value)} />
      </div>
    </div>
  );
}

/* ---------- Stap 5: controleren ---------- */
function StapControleren({ gegevens, wp, opdrachten, fout }) {
  return (
    <div className="max-w-2xl">
      <p className="eyebrow">Controleer je gegevens</p>
      <p className="mb-5 mt-2 text-sm text-ink-700 dark:text-white/65">
        Klopt alles? Klik hieronder op "Formulier opslaan". Je kunt het formulier daarna nog inzien
        op je dashboard en pas indienen wanneer je zeker weet dat het compleet is.
      </p>

      <div className="mb-4 rounded-lg border border-ink-900/8 bg-white p-4 dark:border-white/8 dark:bg-white/[0.03]">
        <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-ink-500 dark:text-white/45">Gegevens</div>
        <div className="grid grid-cols-2 gap-y-1 text-sm text-ink-900 dark:text-white">
          <span>Datum</span><span className="font-medium">{gegevens.datum || '—'}</span>
          <span>Studentnummer</span><span className="font-medium">{gegevens.studentnummer || '—'}</span>
          <span>Klas</span><span className="font-medium">{gegevens.klas || '—'}</span>
          <span>Beoordelaar 1</span><span className="font-medium">{gegevens.beoordelaar_1 || '—'}</span>
          <span>Beoordelaar 2</span><span className="font-medium">{gegevens.beoordelaar_2 || '—'}</span>
        </div>
      </div>

      {WP_CODES.map((code) => {
        const w = wp[code];
        const opdracht = opdrachten.find((o) => o.id === w.opdracht_id);
        return (
          <div key={code} className="mb-4 rounded-lg border border-ink-900/8 bg-white p-4 dark:border-white/8 dark:bg-white/[0.03]">
            <div className="mb-2 text-xs font-semibold uppercase tracking-wide text-ink-500 dark:text-white/45">{WP_LABELS[code]}</div>
            <div className="text-sm font-medium text-ink-900 dark:text-white">{opdracht?.titel || 'Nog geen opdracht gekozen'}</div>
            {w.beoordelmoment && <div className="mt-1 text-[13px] text-ink-500 dark:text-white/45">Beoordelmoment: {w.beoordelmoment}</div>}
          </div>
        );
      })}

      {fout && (
        <div className="rounded-lg border border-rust/40 bg-rust/10 px-4 py-3 text-sm text-rust">{fout}</div>
      )}
    </div>
  );
}

PVBEOF

echo "Writing src/pages/OpdrachtenBeheer.jsx..."
cat > "$FRONT/src/pages/OpdrachtenBeheer.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Ticket, KeyRound, Wrench, Trash2 } from 'lucide-react';
import Layout from '../components/Layout';
import Badge from '../components/Badge';

const cardCls =
  'rounded-lg border border-ink-900/8 bg-white p-4 transition-colors duration-200 ease-crisp dark:border-white/8 dark:bg-white/[0.03]';

// Let op: dit zijn de echte werkproces-codes uit de database check-constraint
// (opdrachten.werkproces IN ('B1-K1-W1','B1-K1-W2','B1-K1-W3')) — niet 'W1'/'W2'/'W3'.
const WERKPROCESSEN = [
  { key: 'B1-K1-W1', label: 'W1 · Handelt meldingen af', icon: Ticket },
  { key: 'B1-K1-W2', label: 'W2 · Instrueert gebruikers', icon: KeyRound },
  { key: 'B1-K1-W3', label: 'W3 · Beheert devices', icon: Wrench },
];

export default function OpdrachtenBeheer() {
  const [tab, setTab] = useState('B1-K1-W1');
  const [opdrachten, setOpdrachten] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);

  function laden() {
    setLoading(true);
    // GET /api/opdrachten/beheer (docent: incl. inactieve)
    axios.get('/api/opdrachten/beheer').then((r) => setOpdrachten(r.data)).catch(() => setOpdrachten([])).finally(() => setLoading(false));
  }

  useEffect(laden, []);

  async function verwijder(id, titel) {
    if (!confirm(`"${titel}" verwijderen? Dit kan niet ongedaan gemaakt worden.`)) return;
    setBusyId(id);
    try {
      // DELETE /api/opdrachten/:id
      await axios.delete(`/api/opdrachten/${id}`);
      laden();
    } catch {
      alert('Verwijderen is niet gelukt.');
    } finally {
      setBusyId(null);
    }
  }

  const rows = opdrachten.filter((o) => o.werkproces === tab);
  const ActiveIcon = WERKPROCESSEN.find((w) => w.key === tab)?.icon || Ticket;

  return (
    <Layout role="docent" title="Opdrachtenbank">
      {/* Tabs per werkproces */}
      <div className="mb-5 flex gap-2 border-b border-ink-900/8 dark:border-white/8">
        {WERKPROCESSEN.map((w) => {
          const count = opdrachten.filter((o) => o.werkproces === w.key).length;
          return (
            <button
              key={w.key}
              onClick={() => setTab(w.key)}
              className={`px-4 py-2.5 text-sm transition-colors ${
                tab === w.key
                  ? 'border-b-2 border-amber font-semibold text-ink-900 dark:text-white'
                  : 'font-medium text-ink-500 dark:text-white/50'
              }`}
            >
              {w.label} <span className="font-mono text-ink-500 dark:text-white/40">{count}</span>
            </button>
          );
        })}
      </div>

      {loading ? (
        <p className="text-sm text-ink-500 dark:text-white/45">Laden…</p>
      ) : rows.length === 0 ? (
        <p className="text-sm text-ink-500 dark:text-white/45">Geen opdrachten voor dit werkproces.</p>
      ) : (
        <div className="flex flex-col gap-3">
          {rows.map((o) => (
            <div key={o.id} className={`${cardCls} flex items-center gap-4 ${!o.is_actief ? 'opacity-60' : ''}`}>
              <span className="flex h-9 w-9 items-center justify-center rounded border border-ink-900/10 text-ink-700 dark:border-white/10 dark:text-white/70">
                <ActiveIcon size={18} strokeWidth={1.75} />
              </span>
              <div className="flex-1">
                <div className="text-[14.5px] font-bold text-ink-900 dark:text-white">{o.titel}</div>
                <div className="mt-0.5 text-[12.5px] text-ink-500 dark:text-white/45">
                  {o.omschrijving}
                  {o.subvragen?.length ? ` · ${o.subvragen.length} subvragen` : ''}
                </div>
              </div>
              <Badge status={o.is_actief ? 'actief' : 'inactief'} />
              <button
                onClick={() => verwijder(o.id, o.titel)}
                disabled={busyId === o.id}
                className="text-ink-500 hover:text-rust disabled:opacity-40 dark:text-white/45"
                aria-label="Verwijderen"
              >
                <Trash2 size={15} />
              </button>
            </div>
          ))}
        </div>
      )}

      <p className="mt-6 text-xs text-ink-500 dark:text-white/40">
        Nieuwe opdrachten aanmaken en bewerken vanuit de UI is nog niet gebouwd — dat kan voorlopig
        via <code className="font-mono">POST</code>/<code className="font-mono">PUT /api/opdrachten</code> of rechtstreeks in de database.
      </p>
    </Layout>
  );
}

PVBEOF

echo "Writing src/pages/DocentDashboard.jsx..."
cat > "$FRONT/src/pages/DocentDashboard.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Search, Download, Check, X } from 'lucide-react';
import Layout from '../components/Layout';
import Badge from '../components/Badge';

const cardCls =
  'rounded-lg border border-ink-900/8 bg-white transition-colors duration-200 ease-crisp dark:border-white/8 dark:bg-white/[0.03]';

function formatDate(d) {
  if (!d) return '';
  return new Date(d).toLocaleDateString('nl-NL', { day: 'numeric', month: 'short', year: 'numeric' });
}

function initialsVan(naam) {
  return (naam || '?').split(' ').map((w) => w[0]).slice(0, 2).join('').toUpperCase();
}

export default function DocentDashboard() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [zoek, setZoek] = useState('');
  const [busyId, setBusyId] = useState(null);

  function laden() {
    setLoading(true);
    // GET /api/formulieren/alle
    axios.get('/api/formulieren/alle').then((r) => setRows(r.data)).catch(() => setRows([])).finally(() => setLoading(false));
  }

  useEffect(laden, []);

  async function beoordeel(id, status) {
    setBusyId(id);
    try {
      // PUT /api/formulieren/:id/beoordeel  { status: 'goedgekeurd' | 'afgekeurd' }
      await axios.put(`/api/formulieren/${id}/beoordeel`, { status });
      laden();
    } catch {
      alert('Beoordelen is niet gelukt.');
    } finally {
      setBusyId(null);
    }
  }

  const gefilterd = rows.filter((r) => {
    const q = zoek.trim().toLowerCase();
    if (!q) return true;
    return (r.student_naam || '').toLowerCase().includes(q) || (r.klas || '').toLowerCase().includes(q);
  });

  const totaal = rows.length;
  const teBeoordelen = rows.filter((r) => r.status === 'ingediend').length;
  const goedgekeurd = rows.filter((r) => r.status === 'goedgekeurd').length;

  const search = (
    <div className="flex min-w-[280px] items-center gap-2.5 rounded border border-ink-900/10 bg-paper px-3.5 py-2 dark:border-white/10 dark:bg-white/[0.03]">
      <Search size={15} className="text-ink-500 dark:text-white/40" />
      <input
        placeholder="Zoek student of klas…"
        value={zoek}
        onChange={(e) => setZoek(e.target.value)}
        className="w-full bg-transparent text-sm text-ink-900 placeholder:text-ink-500 focus:outline-none dark:text-white dark:placeholder:text-white/40"
      />
    </div>
  );

  return (
    <Layout role="docent" title="Alle examenafspraken" right={search}>
      {/* Statistieken */}
      <div className="mb-5 flex gap-3">
        <Stat label="Totaal" value={totaal} />
        <Stat label="Te beoordelen" value={teBeoordelen} accent="text-amber" />
        <Stat label="Goedgekeurd" value={goedgekeurd} accent="text-moss" />
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
            {!loading && gefilterd.length === 0 && (
              <tr><td colSpan={5} className="px-5 py-6 text-center text-ink-500 dark:text-white/45">Geen formulieren gevonden.</td></tr>
            )}
            {gefilterd.map((r) => (
              <tr key={r.id} className="border-t border-ink-900/6 dark:border-white/6">
                <td className="px-5 py-3.5">
                  <div className="flex items-center gap-2.5">
                    <span className="flex h-[30px] w-[30px] items-center justify-center rounded-full border border-ink-900/10 font-mono text-[11px] font-semibold text-ink-700 dark:border-white/15 dark:text-white/70">
                      {initialsVan(r.student_naam)}
                    </span>
                    <span className="font-semibold text-ink-900 dark:text-white">{r.student_naam}</span>
                  </div>
                </td>
                <td className="px-5 py-3.5 text-ink-700 dark:text-white/65">{r.klas}</td>
                <td className="px-5 py-3.5 text-ink-700 dark:text-white/65">{formatDate(r.datum)}</td>
                <td className="px-5 py-3.5"><Badge status={r.status} /></td>
                <td className="px-5 py-3.5">
                  <div className="flex items-center justify-end gap-2">
                    {r.status === 'ingediend' && (
                      <>
                        <button
                          onClick={() => beoordeel(r.id, 'goedgekeurd')}
                          disabled={busyId === r.id}
                          className="inline-flex items-center gap-1 rounded border border-moss/40 px-2.5 py-1.5 text-xs font-semibold text-moss hover:bg-moss/10 disabled:opacity-40"
                        >
                          <Check size={13} /> Goedkeuren
                        </button>
                        <button
                          onClick={() => beoordeel(r.id, 'afgekeurd')}
                          disabled={busyId === r.id}
                          className="inline-flex items-center gap-1 rounded border border-rust/40 px-2.5 py-1.5 text-xs font-semibold text-rust hover:bg-rust/10 disabled:opacity-40"
                        >
                          <X size={13} /> Afkeuren
                        </button>
                      </>
                    )}
                    <a
                      href={`/api/formulieren/${r.id}/export/docx`}
                      className="inline-flex items-center gap-1.5 rounded border border-ink-900/12 px-3 py-1.5 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber dark:border-white/15 dark:text-white"
                    >
                      <Download size={14} /> Word
                    </a>
                  </div>
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

echo "Writing backend/src/routes/export.js..."
cat > "$BACK/src/routes/export.js" << 'PVBEOF'
const express = require("express");
const { execSync, spawnSync } = require("child_process");
const db = require("../db");
const { requireAuth } = require("../middleware/auth");
const path = require("path");
const router = express.Router();

router.get("/:id/export/docx", requireAuth, async (req, res) => {
  try {
    // Studenten mogen alleen hun eigen formulier downloaden; docenten mogen
    // elk formulier downloaden (nodig voor DocentDashboard).
    const result = await db.query(
      "SELECT f.*, u.naam as student_naam FROM formulieren f JOIN users u ON u.id = f.student_id " +
      "WHERE f.id = $1 AND (f.student_id = $2 OR $3 = 'docent')",
      [req.params.id, req.session.user.id, req.session.user.rol]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: "Niet gevonden" });
    const f = result.rows[0];

    const wpResult = await db.query(
      "SELECT fw.*, o.titel, o.omschrijving, o.resultaat FROM formulier_werkprocessen fw JOIN opdrachten o ON o.id = fw.opdracht_id WHERE fw.formulier_id = $1 ORDER BY fw.werkproces",
      [req.params.id]
    );
    const wps = wpResult.rows;
    const getWP = (code) => wps.find(w => w.werkproces === code) || {};
    const w1 = getWP("B1-K1-W1");
    const w2 = getWP("B1-K1-W2");
    const w3 = getWP("B1-K1-W3");

    const formatDate = (d) => d ? new Date(d).toLocaleDateString("nl-NL") : "";

    const data = {
      datum: formatDate(f.datum),
      naam: f.student_naam || "",
      studentnummer: f.studentnummer || "",
      klas: f.klas || "",
      beoordelaar_1: f.beoordelaar_1 || "",
      beoordelaar_2: f.beoordelaar_2 || "",
      w1_titel: w1.titel || "",
      w1_opdracht: w1.omschrijving || "",
      w1_resultaat: w1.resultaat || "",
      w2_titel: w2.titel || "",
      w2_opdracht: w2.omschrijving || "",
      w2_resultaat: w2.resultaat || "",
      w3_titel: w3.titel || "",
      w3_opdracht: w3.omschrijving || "",
      w3_resultaat: w3.resultaat || "",
    };

    const scriptPath = path.join(__dirname, "../../pvb_export.py");
    const env = { ...process.env, TEMPLATE_PATH: "/app/template.docx" };
    const result2 = spawnSync("python3", [scriptPath, JSON.stringify(data)], {
      env,
      maxBuffer: 10 * 1024 * 1024,
    });

    if (result2.status !== 0) {
      console.error("Export fout:", result2.stderr.toString());
      return res.status(500).json({ error: "Export mislukt" });
    }

    const filename = "Examenafspraken_" + f.studentnummer + "_B1-K1.docx";
    res.setHeader("Content-Type", "application/vnd.openxmlformats-officedocument.wordprocessingml.document");
    res.setHeader("Content-Disposition", "attachment; filename=" + filename);
    res.send(result2.stdout);
  } catch (err) {
    console.error("Export fout:", err);
    res.status(500).json({ error: "Export mislukt: " + err.message });
  }
});

module.exports = router;

PVBEOF

echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build frontend backend && docker compose up -d frontend backend"
