// Global charts storage
let charts = {};

// Color schemes
const colors = {
    success: '#00ff64',
    failure: '#ff4444',
    mitigated: '#ffa500',
    primary: '#00d4ff',
    secondary: '#0099cc',
    danger: '#ff1744',
    warning: '#ffa500',
    info: '#00d4ff'
};

const lawColors = ['#ff6b6b', '#ffd93d', '#6bcf7f'];
const modelColors = ['#00d4ff', '#0099cc', '#00ffff', '#00e6b8', '#00d4aa'];

// Tab switching
document.querySelectorAll('.tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const tab = btn.dataset.tab;
        
        document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
        
        btn.classList.add('active');
        document.getElementById(tab).classList.add('active');
        
        loadTabData(tab);
    });
});

// Load overview tab by default
loadTabData('overview');

async function loadTabData(tab) {
    switch(tab) {
        case 'overview':
            loadOverviewTab();
            break;
        case 'ethics':
            loadEthicsTab();
            break;
        case 'robots':
            loadRobotsTab();
            break;
        case 'vulnerability':
            loadVulnerabilityTab();
            break;
        case 'actions':
            loadActionsTab();
            break;
        case 'timeline':
            loadTimelineTab();
            break;
    }
}

// ============================================================================
// TAB: OVERVIEW (Aperçu Général)
// ============================================================================

async function loadOverviewTab() {
    try {
        const [stats, results, robots, laws] = await Promise.all([
            fetch('/api/global-stats').then(r => r.json()),
            fetch('/api/actions-results').then(r => r.json()),
            fetch('/api/robots-status').then(r => r.json()),
            fetch('/api/dilemma-success-by-law').then(r => r.json())
        ]);

        // Update stat cards
        document.querySelector('.stats-grid').innerHTML = `
            <div class="stat-card">
                <div class="stat-label">Total Actions</div>
                <div class="stat-value">${stats.total_actions || 0}</div>
                <div class="stat-unit">décisions éthiques</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Taux Succès Global</div>
                <div class="stat-value">${stats.success_rate || 0}%</div>
                <div class="stat-unit">résolutions correctes</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Robots Opérationnels</div>
                <div class="stat-value">${stats.active_robots || 0}</div>
                <div class="stat-unit">capacité opérationnelle</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Dilemmes Traités</div>
                <div class="stat-value">${stats.total_scenarios || 0}</div>
                <div class="stat-unit">scénarios éthiques</div>
            </div>
        `;

        // Results chart
        createResultsChart(results);

        // Laws complexity chart
        if (laws && laws.length > 0) {
            const lawData = {
                labels: laws.map(l => l.loi_nom || `Loi ${l.loi}`),
                datasets: [{
                    label: 'Taux de Réussite (%)',
                    data: laws.map(l => l.pourcent_succes),
                    backgroundColor: lawColors,
                    borderColor: lawColors,
                    borderWidth: 2
                }]
            };
            
            if (charts.lawsChart) charts.lawsChart.destroy();
            const lawCtx = document.getElementById('lawChart').getContext('2d');
            charts.lawsChart = new Chart(lawCtx, {
                type: 'bar',
                data: lawData,
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    scales: {
                        y: { beginAtZero: true, max: 100 }
                    }
                }
            });
        }

    } catch (error) {
        console.error('Error loading overview:', error);
    }
}

// ============================================================================
// TAB: ETHICS (Dilemmes Éthiques)
// ============================================================================

async function loadEthicsTab() {
    try {
        const [complexity, conflict, timings] = await Promise.all([
            fetch('/api/ethical-complexity').then(r => r.json()),
            fetch('/api/law-conflict-analysis').then(r => r.json()),
            fetch('/api/time-execution-patterns').then(r => r.json())
        ]);

        // Complexité par loi
        if (complexity && complexity.length > 0) {
            const complexData = {
                labels: complexity.map(c => `Loi ${c.loi}`),
                datasets: [{
                    label: 'Difficulté Moyenne',
                    data: complexity.map(c => c.difficulte_moyenne),
                    backgroundColor: lawColors,
                    borderColor: lawColors,
                    borderWidth: 2
                }]
            };
            
            if (charts.complexityChart) charts.complexityChart.destroy();
            const ctx = document.getElementById('complexityChart').getContext('2d');
            charts.complexityChart = new Chart(ctx, {
                type: 'radar',
                data: complexData,
                options: { responsive: true, maintainAspectRatio: true }
            });
        }

        // Conflits inter-lois
        if (conflict && conflict.length > 0) {
            const conflictData = {
                labels: conflict.map(c => c.loi_principale),
                datasets: [{
                    label: 'Taux de Résolution (%)',
                    data: conflict.map(c => c.resolution_rate),
                    backgroundColor: lawColors,
                    borderColor: lawColors,
                    borderWidth: 2
                }]
            };
            
            if (charts.conflictChart) charts.conflictChart.destroy();
            const conflictCtx = document.getElementById('conflictChart').getContext('2d');
            charts.conflictChart = new Chart(conflictCtx, {
                type: 'doughnut',
                data: conflictData,
                options: { responsive: true }
            });
        }

        // Temps d'exécution par type
        if (timings && timings.length > 0) {
            const timingData = {
                labels: timings.map(t => t.categorie_decision),
                datasets: [{
                    label: 'Temps Moyen (ms)',
                    data: timings.map(t => t.temps_moyen_ms),
                    backgroundColor: ['#ff6b6b', '#ffd93d', '#6bcf7f'],
                    borderColor: ['#ff6b6b', '#ffd93d', '#6bcf7f'],
                    borderWidth: 2
                }]
            };
            
            if (charts.timingChart) charts.timingChart.destroy();
            const timingCtx = document.getElementById('timingChart').getContext('2d');
            charts.timingChart = new Chart(timingCtx, {
                type: 'bar',
                data: timingData,
                options: {
                    responsive: true,
                    scales: { y: { beginAtZero: true } }
                }
            });
        }

    } catch (error) {
        console.error('Error loading ethics tab:', error);
    }
}

// ============================================================================
// TAB: ROBOTS (Performance et Spécialisation)
// ============================================================================

async function loadRobotsTab() {
    try {
        const [specialization, maturity] = await Promise.all([
            fetch('/api/robot-specialization-detailed').then(r => r.json()),
            fetch('/api/robot-ethical-maturity').then(r => r.json())
        ]);

        // Spécialisation
        if (specialization && specialization.length > 0) {
            const specData = {
                labels: specialization.map(s => s.nom_robot),
                datasets: [{
                    label: 'Taux de Réussite (%)',
                    data: specialization.map(s => s.taux_reussite),
                    backgroundColor: modelColors.concat(modelColors),
                    borderColor: modelColors.concat(modelColors),
                    borderWidth: 2
                }]
            };
            
            if (charts.specializationChart) charts.specializationChart.destroy();
            const specCtx = document.getElementById('specializationChart').getContext('2d');
            charts.specializationChart = new Chart(specCtx, {
                type: 'horizontalBar',
                data: specData,
                options: {
                    indexAxis: 'y',
                    responsive: true,
                    scales: { x: { beginAtZero: true, max: 100 } }
                }
            });
        }

        // Maturité éthique
        if (maturity && maturity.length > 0) {
            const maturityData = {
                labels: maturity.map(m => m.nom_robot),
                datasets: [{
                    label: 'Taux Dilemmes Difficiles (%)',
                    data: maturity.map(m => m.reussite_dilemmes_durs),
                    backgroundColor: '#ff6b6b',
                    borderColor: '#ff6b6b',
                    borderWidth: 2
                }]
            };
            
            if (charts.maturityChart) charts.maturityChart.destroy();
            const maturityCtx = document.getElementById('maturityChart').getContext('2d');
            charts.maturityChart = new Chart(maturityCtx, {
                type: 'bar',
                data: maturityData,
                options: {
                    responsive: true,
                    scales: { y: { beginAtZero: true, max: 100 } }
                }
            });
        }

    } catch (error) {
        console.error('Error loading robots tab:', error);
    }
}

// ============================================================================
// TAB: VULNERABILITY (Analyse Vulnérabilité)
// ============================================================================

async function loadVulnerabilityTab() {
    try {
        const [vulnerability, sectors] = await Promise.all([
            fetch('/api/vulnerability-impact').then(r => r.json()),
            fetch('/api/sector-ethical-analysis').then(r => r.json())
        ]);

        // Vulnérabilité impact
        if (vulnerability && vulnerability.length > 0) {
            const vulnData = {
                labels: vulnerability.map(v => `Vulnérabilité: ${v.niveau_vulnerabilite}`),
                datasets: [{
                    label: 'Taux Succès (%)',
                    data: vulnerability.map(v => v.taux_reussite),
                    backgroundColor: ['#00ff64', '#ffa500', '#ff4444'],
                    borderColor: ['#00ff64', '#ffa500', '#ff4444'],
                    borderWidth: 2
                }]
            };
            
            if (charts.vulnerabilityChart) charts.vulnerabilityChart.destroy();
            const vulnCtx = document.getElementById('vulnerabilityChart').getContext('2d');
            charts.vulnerabilityChart = new Chart(vulnCtx, {
                type: 'pie',
                data: vulnData,
                options: { responsive: true }
            });
        }

        // Secteurs analysis
        if (sectors && sectors.length > 0) {
            const sectorData = {
                labels: sectors.map(s => s.secteur),
                datasets: [{
                    label: 'Taux Réussite (%)',
                    data: sectors.map(s => s.taux_reussite),
                    backgroundColor: sectors.map((_, i) => modelColors[i % modelColors.length]),
                    borderColor: sectors.map((_, i) => modelColors[i % modelColors.length]),
                    borderWidth: 2
                }]
            };
            
            if (charts.sectorChart) charts.sectorChart.destroy();
            const sectorCtx = document.getElementById('sectorChart').getContext('2d');
            charts.sectorChart = new Chart(sectorCtx, {
                type: 'bar',
                data: sectorData,
                options: {
                    responsive: true,
                    scales: { y: { beginAtZero: true, max: 100 } }
                }
            });
        }

    } catch (error) {
        console.error('Error loading vulnerability tab:', error);
    }
}

// ============================================================================
// TAB: ACTIONS (Catégories d'Actions)
// ============================================================================

async function loadActionsTab() {
    try {
        const data = await fetch('/api/action-categories').then(r => r.json());

        if (data && data.length > 0) {
            const actionData = {
                labels: data.map(a => a.category),
                datasets: [{
                    label: 'Taux Succès (%)',
                    data: data.map(a => a.success_rate),
                    backgroundColor: data.map((_, i) => modelColors[i % modelColors.length]),
                    borderColor: data.map((_, i) => modelColors[i % modelColors.length]),
                    borderWidth: 2
                }]
            };
            
            if (charts.actionsChart) charts.actionsChart.destroy();
            const actionsCtx = document.getElementById('actionsChart').getContext('2d');
            charts.actionsChart = new Chart(actionsCtx, {
                type: 'horizontalBar',
                data: actionData,
                options: {
                    indexAxis: 'y',
                    responsive: true,
                    scales: { x: { beginAtZero: true, max: 100 } }
                }
            });

            // Détail table
            const tableBody = document.getElementById('actionsTableBody');
            tableBody.innerHTML = data.map(a => `
                <tr>
                    <td>${a.category}</td>
                    <td>${a.total}</td>
                    <td>${a.successes}</td>
                    <td><span class="rate-${a.success_rate >= 70 ? 'excellent' : a.success_rate >= 50 ? 'good' : 'poor'}">${a.success_rate}%</span></td>
                </tr>
            `).join('');
        }

    } catch (error) {
        console.error('Error loading actions tab:', error);
    }
}

// ============================================================================
// TAB: TIMELINE
// ============================================================================

async function loadTimelineTab() {
    try {
        // Placeholder for timeline
        const timeline = document.getElementById('timelineList');
        timeline.innerHTML = '<li style="color: #00d4ff; padding: 20px;">⏱️ Timeline historique des décisions...</li>';
    } catch (error) {
        console.error('Error loading timeline:', error);
    }
}

// ============================================================================
// CHART CREATORS
// ============================================================================

function createResultsChart(data) {
    const resultData = {
        labels: (data || []).map(d => d.resultat),
        datasets: [{
            label: 'Résultats Actions',
            data: (data || []).map(d => d.count),
            backgroundColor: ['#00ff64', '#ffa500', '#ff4444'],
            borderColor: ['#00ff64', '#ffa500', '#ff4444'],
            borderWidth: 2
        }]
    };
    
    if (charts.resultsChart) charts.resultsChart.destroy();
    const resultCtx = document.getElementById('resultsChart').getContext('2d');
    charts.resultsChart = new Chart(resultCtx, {
        type: 'doughnut',
        data: resultData,
        options: { responsive: true }
    });
}
