/* ─── Appuntamenti Offline - Android App ─── */
(function () {
    'use strict';

    const DB_NAME = 'AppuntamentiDB';
    const DB_VERSION = 1;
    const STORE_NAME = 'appointments';
    const SETTINGS_STORE = 'settings';
    let db = null;

    // Detect Android bridge
    const isAndroid = typeof Android !== 'undefined';

    // ─── IndexedDB Setup ───
    function openDB() {
        return new Promise((resolve, reject) => {
            const req = indexedDB.open(DB_NAME, DB_VERSION);
            req.onupgradeneeded = (e) => {
                const db = e.target.result;
                if (!db.objectStoreNames.contains(STORE_NAME)) {
                    const store = db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });
                    store.createIndex('status', 'status');
                    store.createIndex('appointment_date', 'appointment_date');
                    store.createIndex('source_sheet', 'source_sheet');
                }
                if (!db.objectStoreNames.contains(SETTINGS_STORE)) {
                    db.createObjectStore(SETTINGS_STORE, { keyPath: 'key' });
                }
            };
            req.onsuccess = (e) => resolve(e.target.result);
            req.onerror = (e) => reject(e.target.error);
        });
    }

    // ─── DB Helpers ───
    function dbOp(storeName, mode, callback) {
        return new Promise((resolve, reject) => {
            const tx = db.transaction(storeName, mode);
            const store = tx.objectStore(storeName);
            const result = callback(store);
            if (result && result.onsuccess !== undefined) {
                result.onsuccess = () => resolve(result.result);
                result.onerror = () => reject(result.error);
            } else {
                tx.oncomplete = () => resolve(result);
                tx.onerror = () => reject(tx.error);
            }
        });
    }

    async function getAll() {
        return dbOp(STORE_NAME, 'readonly', s => s.getAll());
    }

    async function getById(id) {
        return dbOp(STORE_NAME, 'readonly', s => s.get(id));
    }

    async function addRecord(data) {
        return dbOp(STORE_NAME, 'readwrite', s => s.add(data));
    }

    async function putRecord(data) {
        return dbOp(STORE_NAME, 'readwrite', s => s.put(data));
    }

    async function deleteRecord(id) {
        return dbOp(STORE_NAME, 'readwrite', s => s.delete(id));
    }

    async function getCount() {
        return dbOp(STORE_NAME, 'readonly', s => s.count());
    }

    async function getSetting(key, defaultVal) {
        try {
            const r = await dbOp(SETTINGS_STORE, 'readonly', s => s.get(key));
            return r ? r.value : defaultVal;
        } catch { return defaultVal; }
    }

    async function setSetting(key, value) {
        return dbOp(SETTINGS_STORE, 'readwrite', s => s.put({ key, value }));
    }

    // ─── Seed data on first load ───
    async function seedIfNeeded() {
        const count = await getCount();
        if (count > 0) return;
        if (typeof SEED_DATA === 'undefined' || !SEED_DATA.length) return;

        const tx = db.transaction(STORE_NAME, 'readwrite');
        const store = tx.objectStore(STORE_NAME);
        for (const item of SEED_DATA) {
            store.add(item);
        }
        return new Promise((resolve, reject) => {
            tx.oncomplete = resolve;
            tx.onerror = () => reject(tx.error);
        });
    }

    // ─── Toast ───
    function showToast(message, type = 'info') {
        if (isAndroid) {
            Android.showToast(message);
            return;
        }
        const container = document.getElementById('toastContainer');
        const toast = document.createElement('div');
        toast.className = `toast toast-${type}`;
        toast.textContent = message;
        container.appendChild(toast);
        setTimeout(() => toast.remove(), 3000);
    }

    // ─── Notifications via Android Bridge ───
    async function scheduleAppointmentNotifications(app) {
        if (!isAndroid) return;
        if (app.status !== 'pending') return;

        const reminder1Min = await getSetting('reminder1', 60);
        const reminder2Min = await getSetting('reminder2', 15);

        const appDateTime = new Date(`${app.appointment_date}T${app.appointment_time}`);
        const now = Date.now();

        // Reminder 1
        const trigger1 = appDateTime.getTime() - (reminder1Min * 60000);
        if (trigger1 > now) {
            const hLeft = Math.floor(reminder1Min / 60);
            const mLeft = reminder1Min % 60;
            const timeLabel = hLeft > 0 ? `${hLeft}h ${mLeft}m` : `${mLeft} min`;
            const r1Id = app.id * 10 + 1;
            Android.scheduleNotification(
                r1Id,
                '⏰ ' + app.title,
                `Tra ${timeLabel} - ${app.appointment_time.substring(0, 5)}` + (app.description ? '\n' + app.description : ''),
                trigger1
            );
        }

        // Reminder 2
        const trigger2 = appDateTime.getTime() - (reminder2Min * 60000);
        if (trigger2 > now) {
            const r2Id = app.id * 10 + 2;
            Android.scheduleNotification(
                r2Id,
                '🔔 URGENTE: ' + app.title,
                `Tra ${reminder2Min} min! - ${app.appointment_time.substring(0, 5)}` + (app.description ? '\n' + app.description : ''),
                trigger2
            );
        }
    }

    function cancelAppointmentNotifications(appId) {
        if (!isAndroid) return;
        Android.cancelNotification(appId * 10 + 1);
        Android.cancelNotification(appId * 10 + 2);
    }

    async function scheduleAllPendingNotifications() {
        if (!isAndroid) return;
        const all = await getAll();
        const pending = all.filter(a => a.status === 'pending');
        for (const app of pending) {
            await scheduleAppointmentNotifications(app);
        }
    }

    // ─── Rendering ───
    let currentStatus = 'pending';
    let currentSheet = '';
    let searchQuery = '';
    let allAppointments = [];

    const escapeHTML = (str) => {
        if (!str) return '';
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    };

    function getFilteredAppointments() {
        let filtered = allAppointments.filter(a => a.status === currentStatus);
        if (currentSheet) {
            filtered = filtered.filter(a => a.source_sheet === currentSheet);
        }
        if (searchQuery) {
            const q = searchQuery.toLowerCase();
            filtered = filtered.filter(a =>
                (a.title && a.title.toLowerCase().includes(q)) ||
                (a.description && a.description.toLowerCase().includes(q))
            );
        }
        return filtered;
    }

    function renderAppointments() {
        const grid = document.getElementById('appointmentsGrid');
        const filtered = getFilteredAppointments();

        if (filtered.length === 0) {
            grid.innerHTML = `<div class="empty-state">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="1.5" style="margin-bottom:1rem">
                    <rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/>
                    <line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>
                </svg>
                <h3>Nessun appuntamento trovato</h3>
                <p>Prova a cambiare i filtri o aggiungine uno nuovo.</p>
            </div>`;
            return;
        }

        // Group by date
        const groups = {};
        filtered.forEach(a => {
            if (!groups[a.appointment_date]) groups[a.appointment_date] = [];
            groups[a.appointment_date].push(a);
        });

        const sortedDates = Object.keys(groups).sort(
            currentStatus === 'pending' ? (a, b) => a.localeCompare(b) : (a, b) => b.localeCompare(a)
        );

        const todayStr = new Date().toISOString().split('T')[0];

        grid.innerHTML = sortedDates.map((date, idx) => {
            const dateObj = new Date(date + 'T12:00:00');
            const isToday = date === todayStr;
            const apps = groups[date].sort((a, b) => a.appointment_time.localeCompare(b.appointment_time));

            return `<div class="date-row ${isToday ? 'date-today' : ''}" style="animation-delay:${idx * 0.04}s">
                <div class="date-sidebar">
                    <div class="date-day-name">${dateObj.toLocaleDateString('it-IT', { weekday: 'short' })}</div>
                    <div class="date-day-num">${dateObj.getDate()}</div>
                    <div class="date-month">${dateObj.toLocaleDateString('it-IT', { month: 'short', year: 'numeric' })}</div>
                </div>
                <div class="day-content">
                    ${apps.map(app => `
                        <div class="appointment-card status-${app.status}" data-id="${app.id}">
                            <div class="card-title">${escapeHTML(app.title)}</div>
                            <div class="card-time">
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><path d="M12 6v6l4 2"/></svg>
                                ${app.appointment_time.substring(0, 5)}
                            </div>
                            ${app.description ? `<div class="card-desc">${escapeHTML(app.description)}</div>` : ''}
                            <div class="card-footer">
                                <div>
                                    <span class="badge badge-${app.status}">${app.status === 'pending' ? 'in attesa' : app.status === 'completed' ? 'completato' : 'annullato'}</span>
                                    ${app.source_sheet ? `<span class="badge badge-sheet">${escapeHTML(app.source_sheet)}</span>` : ''}
                                </div>
                                <div class="card-actions">
                                    <button class="btn-action btn-action-edit" data-id="${app.id}">✏️</button>
                                    <button class="btn-action btn-action-delete" data-id="${app.id}">🗑️</button>
                                </div>
                            </div>
                        </div>
                    `).join('')}
                </div>
            </div>`;
        }).join('');
    }

    function updateStats() {
        const total = allAppointments.length;
        const pending = allAppointments.filter(a => a.status === 'pending').length;
        const completed = allAppointments.filter(a => a.status === 'completed').length;
        const todayStr = new Date().toISOString().split('T')[0];
        const today = allAppointments.filter(a => a.appointment_date === todayStr).length;

        document.getElementById('statTotal').textContent = total;
        document.getElementById('statPending').textContent = pending;
        document.getElementById('statCompleted').textContent = completed;
        document.getElementById('statToday').textContent = today;
    }

    function populateSheetFilter() {
        const sheets = [...new Set(allAppointments.map(a => a.source_sheet).filter(Boolean))].sort();
        const select = document.getElementById('sheetFilter');
        const currentYear = new Date().getFullYear().toString();
        select.innerHTML = '<option value="">Tutti gli anni</option>' +
            sheets.map(s => `<option value="${s}" ${s === currentYear ? 'selected' : ''}>${s}</option>`).join('');
        if (sheets.includes(currentYear)) {
            currentSheet = currentYear;
        }
    }

    async function refreshAll() {
        allAppointments = await getAll();
        updateStats();
        renderAppointments();
    }

    // ─── Modal Logic ───
    let isEditing = false;
    let editId = null;

    function openModal(editing = false) {
        isEditing = editing;
        const modal = document.getElementById('appointmentModal');
        document.getElementById('modalTitle').textContent = editing ? 'Modifica Appuntamento' : 'Nuovo Appuntamento';
        if (!editing) {
            document.getElementById('appointmentForm').reset();
            document.getElementById('source_sheet').value = new Date().getFullYear().toString();
        }
        modal.style.display = 'flex';
    }

    function closeModal() {
        document.getElementById('appointmentModal').style.display = 'none';
        isEditing = false;
        editId = null;
    }

    async function editAppointment(id) {
        const app = await getById(id);
        if (!app) return;
        editId = id;
        document.getElementById('title').value = app.title;
        document.getElementById('date').value = app.appointment_date;
        document.getElementById('time').value = app.appointment_time;
        document.getElementById('description').value = app.description || '';
        document.getElementById('status').value = app.status;
        document.getElementById('source_sheet').value = app.source_sheet || '';
        openModal(true);
    }

    let deleteTargetId = null;

    function openDeleteModal(id) {
        deleteTargetId = id;
        document.getElementById('deleteModal').style.display = 'flex';
    }

    function closeDeleteModal() {
        document.getElementById('deleteModal').style.display = 'none';
        deleteTargetId = null;
    }

    // ─── Settings Panel ───
    function createSettingsUI() {
        const container = document.getElementById('statsBar');
        const panel = document.createElement('div');
        panel.id = 'settingsPanel';
        panel.className = 'settings-panel';
        panel.style.display = 'none';
        panel.innerHTML = `
            <div class="settings-content">
                <h3>⚙️ Impostazioni Notifiche</h3>
                <div class="settings-row">
                    <label>1° Promemoria (prima):</label>
                    <select id="reminder1Setting" class="form-control" style="width:auto">
                        <option value="15">15 min</option>
                        <option value="30">30 min</option>
                        <option value="60" selected>1 ora</option>
                        <option value="120">2 ore</option>
                        <option value="180">3 ore</option>
                        <option value="360">6 ore</option>
                        <option value="720">12 ore</option>
                        <option value="1440">1 giorno</option>
                        <option value="2880">2 giorni</option>
                    </select>
                </div>
                <div class="settings-row">
                    <label>2° Promemoria (prima):</label>
                    <select id="reminder2Setting" class="form-control" style="width:auto">
                        <option value="5">5 min</option>
                        <option value="10">10 min</option>
                        <option value="15" selected>15 min</option>
                        <option value="30">30 min</option>
                        <option value="60">1 ora</option>
                    </select>
                </div>
                <div class="settings-row">
                    <button id="saveSettingsBtn" class="btn btn-primary" style="margin-top:0.5rem">💾 Salva</button>
                    <button id="testNotifBtn" class="btn btn-secondary" style="margin-top:0.5rem">🔔 Test</button>
                </div>
                <p class="settings-note">${isAndroid ? 'Notifiche native Android attive.' : 'Le notifiche funzionano solo con la pagina aperta.'}</p>
            </div>
        `;
        container.parentNode.insertBefore(panel, container.nextSibling);
    }

    // ─── Import / Export ───
    async function exportData() {
        const all = await getAll();
        const json = JSON.stringify(all, null, 2);
        const blob = new Blob([json], { type: 'application/json' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        const today = new Date().toISOString().split('T')[0];
        a.download = `appuntamenti_${today}.json`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        showToast(`Esportati ${all.length} appuntamenti`, 'success');
    }

    let importFileData = null;

    function openImportModal() {
        document.getElementById('importModal').style.display = 'flex';
    }

    function closeImportModal() {
        document.getElementById('importModal').style.display = 'none';
        importFileData = null;
    }

    async function importData(mode) {
        if (!importFileData) return;
        try {
            const records = JSON.parse(importFileData);
            if (!Array.isArray(records)) {
                showToast('Errore: il file non contiene un array valido', 'error');
                return;
            }

            if (mode === 'replace') {
                // Clear all existing records
                const all = await getAll();
                const tx = db.transaction(STORE_NAME, 'readwrite');
                const store = tx.objectStore(STORE_NAME);
                store.clear();
                await new Promise((resolve, reject) => {
                    tx.oncomplete = resolve;
                    tx.onerror = () => reject(tx.error);
                });
                // Cancel all existing notifications
                if (isAndroid) Android.cancelAllNotifications();
            }

            // Determine new starting ID (for merge mode)
            let maxId = 0;
            if (mode === 'merge') {
                const existing = await getAll();
                maxId = existing.reduce((max, a) => Math.max(max, a.id || 0), 0);
            }

            // Insert records
            const tx2 = db.transaction(STORE_NAME, 'readwrite');
            const store2 = tx2.objectStore(STORE_NAME);
            let count = 0;
            for (const item of records) {
                const record = { ...item };
                if (mode === 'merge') {
                    maxId++;
                    record.id = maxId;
                }
                store2.put(record);
                count++;
            }
            await new Promise((resolve, reject) => {
                tx2.oncomplete = resolve;
                tx2.onerror = () => reject(tx2.error);
            });

            closeImportModal();
            await refreshAll();
            populateSheetFilter();
            await scheduleAllPendingNotifications();
            showToast(`Importati ${count} appuntamenti!`, 'success');
        } catch (err) {
            showToast('Errore importazione: ' + err.message, 'error');
        }
    }

    // Global function for native bridge callback
    window.handleImportedData = function (jsonString) {
        importFileData = jsonString;
        openImportModal();
    };

    // ─── Event Binding ───
    async function init() {
        db = await openDB();
        await seedIfNeeded();
        allAppointments = await getAll();
        populateSheetFilter();
        updateStats();
        renderAppointments();
        createSettingsUI();

        const r1 = await getSetting('reminder1', 60);
        const r2 = await getSetting('reminder2', 15);
        const r1El = document.getElementById('reminder1Setting');
        const r2El = document.getElementById('reminder2Setting');
        if (r1El) r1El.value = r1;
        if (r2El) r2El.value = r2;

        // Request native notification permission
        if (isAndroid) {
            Android.requestPermission();
        }

        // Schedule all pending notifications on load
        await scheduleAllPendingNotifications();

        // Status filter buttons
        document.querySelectorAll('.status-btn').forEach(btn => {
            btn.addEventListener('click', () => {
                document.querySelectorAll('.status-btn').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                currentStatus = btn.dataset.status;
                renderAppointments();
            });
        });

        // Sheet filter
        document.getElementById('sheetFilter').addEventListener('change', (e) => {
            currentSheet = e.target.value;
            renderAppointments();
        });

        // Search
        let searchTimer;
        document.getElementById('searchInput').addEventListener('input', (e) => {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(() => {
                searchQuery = e.target.value.trim();
                renderAppointments();
            }, 250);
        });

        // Add button
        document.getElementById('addBtn').addEventListener('click', () => openModal(false));

        // Modal controls
        document.getElementById('cancelBtn').addEventListener('click', closeModal);
        document.getElementById('closeModalBtn').addEventListener('click', closeModal);
        document.getElementById('appointmentModal').addEventListener('click', (e) => {
            if (e.target === document.getElementById('appointmentModal')) closeModal();
        });

        // Form submit
        document.getElementById('appointmentForm').addEventListener('submit', async (e) => {
            e.preventDefault();
            const timeVal = document.getElementById('time').value;
            const data = {
                title: document.getElementById('title').value.trim(),
                appointment_date: document.getElementById('date').value,
                appointment_time: timeVal.length === 5 ? timeVal + ':00' : timeVal,
                description: document.getElementById('description').value.trim(),
                status: document.getElementById('status').value,
                source_sheet: document.getElementById('source_sheet').value.trim(),
                reminder_sent: 0
            };

            try {
                if (isEditing && editId != null) {
                    data.id = editId;
                    cancelAppointmentNotifications(editId);
                    await putRecord(data);
                    await scheduleAppointmentNotifications(data);
                    showToast('Appuntamento aggiornato!', 'success');
                } else {
                    const all = await getAll();
                    const maxId = all.reduce((max, a) => Math.max(max, a.id || 0), 0);
                    data.id = maxId + 1;
                    await addRecord(data);
                    await scheduleAppointmentNotifications(data);
                    showToast('Appuntamento creato!', 'success');
                }
                closeModal();
                await refreshAll();
                populateSheetFilter();
            } catch (err) {
                showToast('Errore: ' + err.message, 'error');
            }
        });

        // Grid click delegation
        document.getElementById('appointmentsGrid').addEventListener('click', (e) => {
            const editBtn = e.target.closest('.btn-action-edit');
            const deleteBtn = e.target.closest('.btn-action-delete');
            if (editBtn) editAppointment(parseInt(editBtn.dataset.id));
            if (deleteBtn) openDeleteModal(parseInt(deleteBtn.dataset.id));
        });

        // Delete modal
        document.getElementById('cancelDeleteBtn').addEventListener('click', closeDeleteModal);
        document.getElementById('deleteModal').addEventListener('click', (e) => {
            if (e.target === document.getElementById('deleteModal')) closeDeleteModal();
        });
        document.getElementById('confirmDeleteBtn').addEventListener('click', async () => {
            if (deleteTargetId != null) {
                cancelAppointmentNotifications(deleteTargetId);
                await deleteRecord(deleteTargetId);
                showToast('Appuntamento eliminato', 'success');
                closeDeleteModal();
                await refreshAll();
            }
        });

        // Settings toggle via header button
        const headerActions = document.querySelector('.header-actions');
        const settingsBtn = document.createElement('button');
        settingsBtn.className = 'btn btn-secondary';
        settingsBtn.innerHTML = '⚙️';
        settingsBtn.title = 'Impostazioni';
        settingsBtn.style.padding = '10px 14px';
        headerActions.insertBefore(settingsBtn, headerActions.firstChild);

        settingsBtn.addEventListener('click', () => {
            const panel = document.getElementById('settingsPanel');
            panel.style.display = panel.style.display === 'none' ? 'block' : 'none';
        });

        // Import/Export buttons in header
        const exportBtn = document.createElement('button');
        exportBtn.className = 'btn btn-secondary';
        exportBtn.innerHTML = '📤';
        exportBtn.title = 'Esporta dati';
        exportBtn.style.padding = '10px 14px';
        headerActions.insertBefore(exportBtn, headerActions.firstChild);
        exportBtn.addEventListener('click', exportData);

        const importBtn = document.createElement('button');
        importBtn.className = 'btn btn-secondary';
        importBtn.innerHTML = '📥';
        importBtn.title = 'Importa dati';
        importBtn.style.padding = '10px 14px';
        headerActions.insertBefore(importBtn, headerActions.firstChild);
        importBtn.addEventListener('click', () => {
            document.getElementById('importFileInput').click();
        });

        // File input change handler
        document.getElementById('importFileInput').addEventListener('change', (e) => {
            const file = e.target.files[0];
            if (!file) return;
            const reader = new FileReader();
            reader.onload = (ev) => {
                importFileData = ev.target.result;
                openImportModal();
            };
            reader.readAsText(file);
            e.target.value = ''; // Reset so same file can be re-selected
        });

        // Import modal handlers
        document.getElementById('importMergeBtn').addEventListener('click', () => importData('merge'));
        document.getElementById('importReplaceBtn').addEventListener('click', () => importData('replace'));
        document.getElementById('importCancelBtn').addEventListener('click', closeImportModal);
        document.getElementById('importModal').addEventListener('click', (e) => {
            if (e.target === document.getElementById('importModal')) closeImportModal();
        });

        // Save settings
        document.getElementById('saveSettingsBtn').addEventListener('click', async () => {
            const r1 = parseInt(document.getElementById('reminder1Setting').value);
            const r2 = parseInt(document.getElementById('reminder2Setting').value);
            await setSetting('reminder1', r1);
            await setSetting('reminder2', r2);
            // Re-schedule all notifications with new settings
            await scheduleAllPendingNotifications();
            showToast('Impostazioni salvate!', 'success');
        });

        // Test notification
        document.getElementById('testNotifBtn').addEventListener('click', () => {
            if (isAndroid) {
                Android.scheduleNotification(99999, '🔔 Test Notifica', 'Le notifiche funzionano correttamente!', Date.now() + 3000);
                showToast('Notifica di test tra 3 secondi', 'info');
            } else {
                showToast('Test disponibile solo su Android', 'info');
            }
        });

        // Escape closes modals
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') { closeModal(); closeDeleteModal(); }
        });
    }

    document.addEventListener('DOMContentLoaded', init);
})();
