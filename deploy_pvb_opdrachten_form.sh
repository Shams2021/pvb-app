#!/bin/bash
set -e
FRONT=/opt/bvp-app/frontend
echo "Backing up..."
cp -r "$FRONT" "$FRONT.backup-opdrachten-$(date +%F-%H%M)"
echo "Writing src/pages/OpdrachtenBeheer.jsx..."
cat > "$FRONT/src/pages/OpdrachtenBeheer.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Ticket, KeyRound, Wrench, Trash2, Plus, X, Loader2 } from 'lucide-react';
import Layout from '../components/Layout';
import Badge from '../components/Badge';

const cardCls =
  'rounded-lg border border-ink-900/8 bg-white p-4 transition-colors duration-200 ease-crisp dark:border-white/8 dark:bg-white/[0.03]';
const inputCls =
  'w-full rounded border px-3.5 py-2.5 text-sm text-ink-900 placeholder:text-ink-500 border-ink-900/15 bg-white dark:text-white dark:placeholder:text-white/35 dark:border-white/15 dark:bg-white/[0.05]';
const labelCls = 'mb-1.5 block text-xs font-semibold text-ink-900 dark:text-white';

// Echte werkproces-codes uit de database check-constraint (niet 'W1'/'W2'/'W3').
const WERKPROCESSEN = [
  { key: 'B1-K1-W1', label: 'W1 · Handelt meldingen af', icon: Ticket },
  { key: 'B1-K1-W2', label: 'W2 · Instrueert gebruikers', icon: KeyRound },
  { key: 'B1-K1-W3', label: 'W3 · Beheert devices', icon: Wrench },
];

const leegFormulier = () => ({ titel: '', omschrijving: '', resultaat: '', subvragen: [''] });

export default function OpdrachtenBeheer() {
  const [tab, setTab] = useState('B1-K1-W1');
  const [opdrachten, setOpdrachten] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);
  const [toonForm, setToonForm] = useState(false);
  const [nieuw, setNieuw] = useState(leegFormulier());
  const [opslaan, setOpslaan] = useState(false);
  const [fout, setFout] = useState('');

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

  function openForm() {
    setNieuw(leegFormulier());
    setFout('');
    setToonForm(true);
  }

  function subvraagWijzig(i, tekst) {
    setNieuw((n) => {
      const subvragen = [...n.subvragen];
      subvragen[i] = tekst;
      return { ...n, subvragen };
    });
  }
  function subvraagToevoegen() {
    setNieuw((n) => ({ ...n, subvragen: [...n.subvragen, ''] }));
  }
  function subvraagVerwijderen(i) {
    setNieuw((n) => ({ ...n, subvragen: n.subvragen.filter((_, idx) => idx !== i) }));
  }

  async function opslaanOpdracht() {
    if (!nieuw.titel.trim() || !nieuw.omschrijving.trim() || !nieuw.resultaat.trim()) {
      setFout('Titel, omschrijving en resultaat zijn verplicht.');
      return;
    }
    setOpslaan(true);
    setFout('');
    const volgorde = opdrachten.filter((o) => o.werkproces === tab).length + 1;
    const subvragen = nieuw.subvragen.filter((v) => v.trim()).map((vraag) => ({ vraag }));
    try {
      // POST /api/opdrachten
      await axios.post('/api/opdrachten', {
        werkproces: tab,
        titel: nieuw.titel,
        omschrijving: nieuw.omschrijving,
        resultaat: nieuw.resultaat,
        volgorde,
        subvragen,
      });
      setToonForm(false);
      laden();
    } catch {
      setFout('Opslaan is niet gelukt. Probeer het opnieuw.');
    } finally {
      setOpslaan(false);
    }
  }

  const rows = opdrachten.filter((o) => o.werkproces === tab);
  const ActiveIcon = WERKPROCESSEN.find((w) => w.key === tab)?.icon || Ticket;

  const NieuweBtn = (
    <button
      onClick={openForm}
      className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600"
    >
      <Plus size={17} strokeWidth={2} /> Nieuwe opdracht
    </button>
  );

  return (
    <Layout role="docent" title="Opdrachtenbank" right={NieuweBtn}>
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

      {/* Nieuw-opdracht formulier, alleen zichtbaar na klik op de knop */}
      {toonForm && (
        <div className={`${cardCls} mb-4`}>
          <div className="mb-3 flex items-center justify-between">
            <p className="text-sm font-bold text-ink-900 dark:text-white">
              Nieuwe opdracht voor {WERKPROCESSEN.find((w) => w.key === tab)?.label}
            </p>
            <button onClick={() => setToonForm(false)} className="text-ink-500 hover:text-ink-900 dark:text-white/45 dark:hover:text-white">
              <X size={18} />
            </button>
          </div>

          <div className="mb-3">
            <label className={labelCls}>Titel</label>
            <input className={inputCls} value={nieuw.titel} onChange={(e) => setNieuw({ ...nieuw, titel: e.target.value })} placeholder="Bijv. Netwerkstoring oplossen" />
          </div>
          <div className="mb-3">
            <label className={labelCls}>Omschrijving</label>
            <textarea rows={2} className={`${inputCls} resize-none`} value={nieuw.omschrijving} onChange={(e) => setNieuw({ ...nieuw, omschrijving: e.target.value })} placeholder="Wat houdt de opdracht in?" />
          </div>
          <div className="mb-3">
            <label className={labelCls}>Resultaat</label>
            <textarea rows={2} className={`${inputCls} resize-none`} value={nieuw.resultaat} onChange={(e) => setNieuw({ ...nieuw, resultaat: e.target.value })} placeholder="Wat moet er opgeleverd zijn?" />
          </div>

          <div className="mb-3">
            <label className={labelCls}>Subvragen (optioneel)</label>
            <div className="flex flex-col gap-2">
              {nieuw.subvragen.map((v, i) => (
                <div key={i} className="flex gap-2">
                  <input className={inputCls} value={v} onChange={(e) => subvraagWijzig(i, e.target.value)} placeholder={`Subvraag ${i + 1}`} />
                  {nieuw.subvragen.length > 1 && (
                    <button onClick={() => subvraagVerwijderen(i)} className="text-ink-500 hover:text-rust dark:text-white/45" aria-label="Subvraag verwijderen">
                      <X size={16} />
                    </button>
                  )}
                </div>
              ))}
            </div>
            <button onClick={subvraagToevoegen} className="mt-2 text-xs font-semibold text-amber hover:underline">
              + Subvraag toevoegen
            </button>
          </div>

          {fout && <p className="mb-3 text-sm text-rust">{fout}</p>}

          <button
            onClick={opslaanOpdracht}
            disabled={opslaan}
            className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600 disabled:opacity-60"
          >
            {opslaan ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
            {opslaan ? 'Bezig…' : 'Opdracht opslaan'}
          </button>
        </div>
      )}

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
        Bestaande opdrachten bewerken vanuit de UI is nog niet gebouwd — dat kan voorlopig via <code className="font-mono">PUT /api/opdrachten/:id</code>.
      </p>
    </Layout>
  );
}

PVBEOF
echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build frontend && docker compose up -d frontend"
