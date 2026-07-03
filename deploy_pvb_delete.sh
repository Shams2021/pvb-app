#!/bin/bash
set -e
FRONT=/opt/bvp-app/frontend
BACK=/opt/bvp-app/backend
echo "Backing up..."
cp -r "$FRONT" "$FRONT.backup-delete-$(date +%F-%H%M)"
cp -r "$BACK" "$BACK.backup-delete-$(date +%F-%H%M)"

echo "Writing src/pages/Dashboard.jsx..."
cat > "$FRONT/src/pages/Dashboard.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Plus, FilePlus2, FileCheck2, FilePenLine, CheckCheck, XCircle, Download, Send, Trash2 } from 'lucide-react';
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

  async function verwijder(id) {
    if (!confirm('Dit concept verwijderen? Dit kan niet ongedaan gemaakt worden.')) return;
    setBusyId(id);
    try {
      // DELETE /api/formulieren/:id — alleen toegestaan zolang status 'concept' is
      await axios.delete(`/api/formulieren/${id}`);
      laden();
    } catch (err) {
      alert(err?.response?.data?.error || 'Verwijderen is niet gelukt.');
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
        <FormulierList items={formulieren} busyId={busyId} onIndienen={dienIn} onVerwijder={verwijder} />
      )}
    </Layout>
  );
}

/* ---------- Lege staat ---------- */
function EmptyState() {
  const steps = [
    { n: 1, t: 'Vul het formulier in', s: 'W1, W2 en W3.' },
    { n: 2, t: 'Download als Word', s: 'Onderteken het.' },
    { n: 3, t: 'Dien in via Canvas', s: 'Zet daarna op "ingediend".' },
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

function FormulierList({ items, busyId, onIndienen, onVerwijder }) {
  return (
    <div className="mt-4 flex flex-col gap-3">
      {items.map((f) => {
        const Icon = ICONS[f.status] || FilePenLine;
        const werkprocessenCompleet = Array.isArray(f.werkprocessen) ? f.werkprocessen.length : 0;
        const isBusy = busyId === f.id;
        return (
          <div key={f.id} className={`${cardCls} flex items-center gap-4`}>
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

            {/* GET /api/formulieren/:id/export/docx — altijd beschikbaar, ook voor concepten
                (je download 'm, ondertekent 'm, en levert 'm apart in via Canvas) */}
            <a
              href={`/api/formulieren/${f.id}/export/docx`}
              className="inline-flex items-center gap-1.5 rounded border border-ink-900/15 px-3 py-1.5 text-sm font-semibold text-ink-900 hover:border-amber/50 hover:text-amber dark:border-white/15 dark:text-white"
            >
              <Download size={14} /> Word
            </a>

            {f.status === 'concept' && (
              <>
                <button
                  onClick={() => onIndienen(f.id)}
                  disabled={isBusy}
                  className="inline-flex items-center gap-1.5 rounded bg-amber px-3 py-1.5 text-sm font-semibold text-carbon-900 hover:bg-amber-600 disabled:opacity-50"
                >
                  <Send size={14} /> {isBusy ? 'Bezig…' : 'Dien in'}
                </button>
                <button
                  onClick={() => onVerwijder(f.id)}
                  disabled={isBusy}
                  className="text-ink-500 hover:text-rust disabled:opacity-40 dark:text-white/45"
                  aria-label="Verwijderen"
                >
                  <Trash2 size={16} />
                </button>
              </>
            )}
          </div>
        );
      })}
    </div>
  );
}

PVBEOF

echo "Writing src/pages/DocentDashboard.jsx..."
cat > "$FRONT/src/pages/DocentDashboard.jsx" << 'PVBEOF'
import { useEffect, useState } from 'react';
import axios from 'axios';
import { Search, Download, Check, X, Trash2 } from 'lucide-react';
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

  async function verwijder(id, studentNaam) {
    if (!confirm(`Formulier van ${studentNaam} verwijderen? Dit kan niet ongedaan gemaakt worden.`)) return;
    setBusyId(id);
    try {
      // DELETE /api/formulieren/:id — docent mag elke status verwijderen
      await axios.delete(`/api/formulieren/${id}`);
      laden();
    } catch (err) {
      alert(err?.response?.data?.error || 'Verwijderen is niet gelukt.');
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
                    <button
                      onClick={() => verwijder(r.id, r.student_naam)}
                      disabled={busyId === r.id}
                      className="text-ink-500 hover:text-rust disabled:opacity-40 dark:text-white/45"
                      aria-label="Verwijderen"
                    >
                      <Trash2 size={15} />
                    </button>
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

echo "Writing backend/src/routes/formulieren.js..."
cat > "$BACK/src/routes/formulieren.js" << 'PVBEOF'
const express = require('express');
const db = require('../db');
const { requireAuth, requireDocent } = require('../middleware/auth');
const router = express.Router();

router.get('/mijn', requireAuth, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT f.*, json_agg(json_build_object(' +
      "'werkproces', fw.werkproces, " +
      "'opdracht_titel', o.titel, " +
      "'aanvullende_afspraken', fw.aanvullende_afspraken, " +
      "'periode_start', fw.periode_start, " +
      "'periode_einde', fw.periode_einde, " +
      "'beoordelmoment', fw.beoordelmoment" +
      ')) FILTER (WHERE fw.id IS NOT NULL) as werkprocessen ' +
      'FROM formulieren f ' +
      'LEFT JOIN formulier_werkprocessen fw ON fw.formulier_id = f.id ' +
      'LEFT JOIN opdrachten o ON o.id = fw.opdracht_id ' +
      'WHERE f.student_id = $1 ' +
      'GROUP BY f.id ORDER BY f.created_at DESC',
      [req.session.user.id]
    );
    res.json(result.rows);
  } catch (err) {
    console.error('formulieren/mijn fout:', err);
    res.status(500).json({ error: 'Server fout' });
  }
});

router.get('/alle', requireDocent, async (req, res) => {
  try {
    const result = await db.query(
      'SELECT f.*, u.naam as student_naam, u.email as student_email, ' +
      'json_agg(json_build_object(' +
      "'werkproces', fw.werkproces, 'opdracht_titel', o.titel" +
      ')) FILTER (WHERE fw.id IS NOT NULL) as werkprocessen ' +
      'FROM formulieren f ' +
      'JOIN users u ON u.id = f.student_id ' +
      'LEFT JOIN formulier_werkprocessen fw ON fw.formulier_id = f.id ' +
      'LEFT JOIN opdrachten o ON o.id = fw.opdracht_id ' +
      'GROUP BY f.id, u.naam, u.email ORDER BY f.created_at DESC'
    );
    res.json(result.rows);
  } catch (err) {
    console.error('formulieren/alle fout:', err);
    res.status(500).json({ error: 'Server fout' });
  }
});

router.post('/', requireAuth, async (req, res) => {
  const { datum, studentnummer, klas, beoordelaar_1, beoordelaar_2, werkprocessen } = req.body;
  const client = await db.pool.connect();
  try {
    await client.query('BEGIN');
    const formResult = await client.query(
      'INSERT INTO formulieren (student_id, datum, studentnummer, klas, beoordelaar_1, beoordelaar_2) VALUES ($1, $2, $3, $4, $5, $6) RETURNING *',
      [req.session.user.id, datum, studentnummer, klas, beoordelaar_1, beoordelaar_2]
    );
    const formulier = formResult.rows[0];
    for (const wp of werkprocessen) {
      const wpResult = await client.query(
        'INSERT INTO formulier_werkprocessen (formulier_id, werkproces, opdracht_id, aanvullende_afspraken, periode_start, periode_einde, beoordelmoment, specifieke_details) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *',
        [formulier.id, wp.werkproces, wp.opdracht_id, wp.aanvullende_afspraken || null, wp.periode_start || null, wp.periode_einde || null, wp.beoordelmoment || null, JSON.stringify(wp.specifieke_details || {})]
      );
      if (wp.subvraag_antwoorden && wp.subvraag_antwoorden.length > 0) {
        for (const antwoord of wp.subvraag_antwoorden) {
          await client.query(
            'INSERT INTO subvraag_antwoorden (formulier_werkproces_id, subvraag_id, antwoord) VALUES ($1, $2, $3)',
            [wpResult.rows[0].id, antwoord.subvraag_id, antwoord.antwoord]
          );
        }
      }
    }
    await client.query('COMMIT');
    res.status(201).json(formulier);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error('formulier post fout:', err);
    res.status(500).json({ error: 'Server fout' });
  } finally {
    client.release();
  }
});

router.put('/:id/indienen', requireAuth, async (req, res) => {
  try {
    const result = await db.query(
      "UPDATE formulieren SET status = 'ingediend', updated_at = NOW() WHERE id = $1 AND student_id = $2 AND status = 'concept' RETURNING *",
      [req.params.id, req.session.user.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'Formulier niet gevonden' });
    res.json(result.rows[0]);
  } catch (err) {
    console.error('indienen fout:', err);
    res.status(500).json({ error: 'Server fout' });
  }
});

router.put('/:id/beoordeel', requireDocent, async (req, res) => {
  const { status } = req.body;
  if (!['goedgekeurd', 'afgekeurd'].includes(status)) {
    return res.status(400).json({ error: 'Ongeldige status' });
  }
  try {
    const result = await db.query(
      'UPDATE formulieren SET status = $1, updated_at = NOW() WHERE id = $2 RETURNING *',
      [status, req.params.id]
    );
    res.json(result.rows[0]);
  } catch (err) {
    console.error('beoordeel fout:', err);
    res.status(500).json({ error: 'Server fout' });
  }
});

// Verwijderregel:
//   - status 'concept'  → de eigenaar (student) of een docent mag verwijderen
//   - elke andere status (ingediend/goedgekeurd/afgekeurd) → alleen een docent
router.delete('/:id', requireAuth, async (req, res) => {
  try {
    const result = await db.query('SELECT student_id, status FROM formulieren WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) return res.status(404).json({ error: 'Niet gevonden' });
    const f = result.rows[0];
    const isEigenaar = f.student_id === req.session.user.id;
    const isDocent = req.session.user.rol === 'docent';

    if (f.status === 'concept') {
      if (!isEigenaar && !isDocent) {
        return res.status(403).json({ error: 'Geen toegang tot dit formulier' });
      }
    } else if (!isDocent) {
      return res.status(403).json({ error: 'Een ingediend formulier kan alleen door een docent verwijderd worden' });
    }

    await db.query('DELETE FROM formulieren WHERE id = $1', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    console.error('formulier delete fout:', err);
    res.status(500).json({ error: 'Server fout' });
  }
});

module.exports = router;

PVBEOF

echo "Klaar. Volgende stap:"
echo "cd /opt/bvp-app && docker compose build frontend backend && docker compose up -d frontend backend"
