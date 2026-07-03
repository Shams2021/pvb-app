#!/bin/bash
set -e
FRONT=/opt/bvp-app/frontend
echo "Backing up..."
cp -r "$FRONT" "$FRONT.backup-edit-$(date +%F-%H%M)"
echo "Writing src/pages/OpdrachtenBeheer.jsx..."
cat > "$FRONT/src/pages/OpdrachtenBeheer.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Ticket, KeyRound, Wrench, Trash2, Plus, Pencil, X, Loader2 } from 'lucide-react';
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

const leegFormulier = () => ({ titel: '', omschrijving: '', resultaat: '', is_actief: true, subvragen: [''] });

export default function OpdrachtenBeheer() {
  const [tab, setTab] = useState('B1-K1-W1');
  const [opdrachten, setOpdrachten] = useState([]);
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState(null);

  const [toonForm, setToonForm] = useState(false);
  const [bewerkId, setBewerkId] = useState(null); // null = nieuw aanmaken, anders id van opdracht die bewerkt wordt
  const [form, setForm] = useState(leegFormulier());
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

  function openNieuw() {
    setBewerkId(null);
    setForm(leegFormulier());
    setFout('');
    setToonForm(true);
  }

  function openBewerken(o) {
    setBewerkId(o.id);
    setForm({
      titel: o.titel,
      omschrijving: o.omschrijving,
      resultaat: o.resultaat,
      is_actief: o.is_actief,
      subvragen: o.subvragen?.length ? o.subvragen.map((s) => s.vraag) : [''],
    });
    setFout('');
    setToonForm(true);
  }

  function subvraagWijzig(i, tekst) {
    setForm((f) => {
      const subvragen = [...f.subvragen];
      subvragen[i] = tekst;
      return { ...f, subvragen };
    });
  }
  function subvraagToevoegen() {
    setForm((f) => ({ ...f, subvragen: [...f.subvragen, ''] }));
  }
  function subvraagVerwijderen(i) {
    setForm((f) => ({ ...f, subvragen: f.subvragen.filter((_, idx) => idx !== i) }));
  }

  async function opslaan_() {
    if (!form.titel.trim() || !form.omschrijving.trim() || !form.resultaat.trim()) {
      setFout('Titel, omschrijving en resultaat zijn verplicht.');
      return;
    }
    setOpslaan(true);
    setFout('');
    const subvragen = form.subvragen.filter((v) => v.trim()).map((vraag) => ({ vraag }));
    try {
      if (bewerkId) {
        const bestaand = opdrachten.find((o) => o.id === bewerkId);
        // PUT /api/opdrachten/:id
        await axios.put(`/api/opdrachten/${bewerkId}`, {
          titel: form.titel,
          omschrijving: form.omschrijving,
          resultaat: form.resultaat,
          volgorde: bestaand?.volgorde ?? 0,
          is_actief: form.is_actief,
          subvragen,
        });
      } else {
        const volgorde = opdrachten.filter((o) => o.werkproces === tab).length + 1;
        // POST /api/opdrachten
        await axios.post('/api/opdrachten', {
          werkproces: tab,
          titel: form.titel,
          omschrijving: form.omschrijving,
          resultaat: form.resultaat,
          volgorde,
          subvragen,
        });
      }
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
      onClick={openNieuw}
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

      {/* Aanmaak-/bewerkformulier */}
      {toonForm && (
        <div className={`${cardCls} mb-4`}>
          <div className="mb-3 flex items-center justify-between">
            <p className="text-sm font-bold text-ink-900 dark:text-white">
              {bewerkId ? 'Opdracht bewerken' : `Nieuwe opdracht voor ${WERKPROCESSEN.find((w) => w.key === tab)?.label}`}
            </p>
            <button onClick={() => setToonForm(false)} className="text-ink-500 hover:text-ink-900 dark:text-white/45 dark:hover:text-white">
              <X size={18} />
            </button>
          </div>

          <div className="mb-3">
            <label className={labelCls}>Titel</label>
            <input className={inputCls} value={form.titel} onChange={(e) => setForm({ ...form, titel: e.target.value })} placeholder="Bijv. Netwerkstoring oplossen" />
          </div>
          <div className="mb-3">
            <label className={labelCls}>Omschrijving</label>
            <textarea rows={2} className={`${inputCls} resize-none`} value={form.omschrijving} onChange={(e) => setForm({ ...form, omschrijving: e.target.value })} placeholder="Wat houdt de opdracht in?" />
          </div>
          <div className="mb-3">
            <label className={labelCls}>Resultaat</label>
            <textarea rows={2} className={`${inputCls} resize-none`} value={form.resultaat} onChange={(e) => setForm({ ...form, resultaat: e.target.value })} placeholder="Wat moet er opgeleverd zijn?" />
          </div>

          {bewerkId && (
            <label className="mb-3 flex items-center gap-2 text-sm text-ink-900 dark:text-white">
              <input type="checkbox" checked={form.is_actief} onChange={(e) => setForm({ ...form, is_actief: e.target.checked })} />
              Actief (zichtbaar voor studenten in de wizard)
            </label>
          )}

          <div className="mb-3">
            <label className={labelCls}>Subvragen (optioneel)</label>
            <div className="flex flex-col gap-2">
              {form.subvragen.map((v, i) => (
                <div key={i} className="flex gap-2">
                  <input className={inputCls} value={v} onChange={(e) => subvraagWijzig(i, e.target.value)} placeholder={`Subvraag ${i + 1}`} />
                  {form.subvragen.length > 1 && (
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
            onClick={opslaan_}
            disabled={opslaan}
            className="inline-flex items-center gap-2 rounded bg-amber px-4 py-2 text-sm font-semibold text-carbon-900 hover:bg-amber-600 disabled:opacity-60"
          >
            {opslaan ? <Loader2 size={16} className="animate-spin" /> : <Plus size={16} />}
            {opslaan ? 'Bezig…' : bewerkId ? 'Wijzigingen opslaan' : 'Opdracht opslaan'}
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
              <button onClick={() => openBewerken(o)} className="text-ink-500 hover:text-amber dark:text-white/45" aria-label="Bewerken">
                <Pencil size={15} />
              </button>
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
    </Layout>
  );
}

PVBEOF
echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build frontend && docker compose up -d frontend"
