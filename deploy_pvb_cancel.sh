#!/bin/bash
set -e
FRONT=/opt/bvp-app/frontend
echo "Backing up..."
cp -r "$FRONT" "$FRONT.backup-cancel-$(date +%F-%H%M)"
echo "Writing src/pages/FormulierInvullen.jsx..."
cat > "$FRONT/src/pages/FormulierInvullen.jsx" << 'PVBEOF'
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import axios from 'axios';
import { CheckCircle2, ArrowLeft, ArrowRight, Loader2, X } from 'lucide-react';
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

  function annuleren() {
    if (confirm('Weet je zeker dat je wilt stoppen? Wat je hebt ingevuld gaat verloren, er wordt niets opgeslagen.')) {
      navigate('/dashboard');
    }
  }

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
          <div className="flex items-center gap-3">
            <button
              onClick={annuleren}
              className="inline-flex items-center gap-1.5 rounded px-3 py-1.5 text-sm font-medium text-ink-500 hover:text-rust dark:text-white/50"
            >
              <X size={16} /> Annuleren
            </button>
            <ThemeToggle />
          </div>
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
echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build frontend && docker compose up -d frontend"
