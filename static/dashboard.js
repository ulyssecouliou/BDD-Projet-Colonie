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
const resultColors = {
    'succes': '#00ff64',
    'mitigue': '#ffa500',
    'echec': '#ff4444'
};

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
// TAB: OVERVIEW
// ============================================================================

async function loadOverviewTab() {
    try {
        const [stats, results, robots, vulns] = await Promise.all([
            fetch('/api/global-stats').then(r => r.json()),
            fetch('/api/actions-results').then(r => r.json()),
            fetch('/api/robots-status').then(r => r.json()),
            fetch('/api/humains-vulnerability').then(r => r.json())
        ]);

        // Update stat cards
        document.querySelectorAll('.stat-value')[0].textContent = stats.total_actions || 0;
        document.querySelectorAll('.stat-value')[1].textContent = (stats.success_rate || 0) + '%';
        document.querySelectorAll('.stat-value')[2].textContent = stats.active_robots || 0;
        document.querySelectorAll('.stat-value')[3].textContent = stats.total_scenarios || 0;

        // Results chart
        if (results && results.length > 0) {
            const ctx = document.getElementById('resultsChart').getContext('2d');
            if (charts.resultsChart) charts.resultsChart.destroy();
            
            charts.resultsChart = new Chart(ctx, {
                type: 'doughnut',
                data: {
                    labels: results.map(r => r.resultat),
                    datasets: [{
                        data: results.map(r => r.count),
                        backgroundColor: results.map(r => resultColors[r.resultat] || '#999')
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    plugins: {
                        legend: { position: 'bottom' }
                    }
                }
            });
        }

        // Vulnerability chart
        if (vulns && vulns.length > 0) {
            const ctx = document.getElementById('vulnerabilityChart').getContext('2d');
            if (charts.vulnerabilityChart) charts.vulnerabilityChart.destroy();
            
            charts.vulnerabilityChart = new Chart(ctx, {
                type: 'pie',
                data: {
                    labels: vulns.map(v => v.vulnerabilite),
                    datasets: [{
                        data: vulns.map(v => v.count),
                        backgroundColor: ['#6bcf7f', '#ffd93d', '#ff6b6b']
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    plugins: {
                        legend: { position: 'bottom' }
                    }
                }
            });
        }

        // Robot status chart
        if (robots && robots.length > 0) {
            const ctx = document.getElementById('robotStatusChart').getContext('2d');
            if (charts.robotStatusChart) charts.robotStatusChart.destroy();
            
            charts.robotStatusChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: robots.map(r => r.modele + ' (' + r.etat + ')'),
                    datasets: [{
                        label: 'Nombre de robots',
                        data: robots.map(r => r.count),
                        backgroundColor: '#00d4ff',
                        borderColor: '#0099cc',
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    indexAxis: 'y',
                    scales: {
                        x: { beginAtZero: true }
                    }
                }
            });
        }

        // Model performance chart
        const perf = await fetch('/api/performance-by-model').then(r => r.json());
        if (perf && perf.length > 0) {
            const ctx = document.getElementById('modelPerformanceChart').getContext('2d');
            if (charts.modelPerformanceChart) charts.modelPerformanceChart.destroy();
            
            charts.modelPerformanceChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: perf.map(p => p.modele),
                    datasets: [{
                        label: 'Taux de Réussite (%)',
                        data: perf.map(p => p.success_rate || 0),
                        backgroundColor: perf.map(p => {
                            const rate = p.success_rate || 0;
                            if (rate >= 75) return '#00ff64';
                            if (rate >= 50) return '#ffd93d';
                            return '#ff4444';
                        })
                    }]
                },
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
// TAB: ETHICS
// ============================================================================

async function loadEthicsTab() {
    try {
        const [complexity, success] = await Promise.all([
            fetch('/api/ethical-complexity').then(r => r.json()),
            fetch('/api/dilemma-success-by-law').then(r => r.json())
        ]);

        // Ethical laws chart
        if (complexity && complexity.length > 0) {
            const ctx = document.getElementById('ethicalLawsChart').getContext('2d');
            if (charts.ethicalLawsChart) charts.ethicalLawsChart.destroy();
            
            charts.ethicalLawsChart = new Chart(ctx, {
                type: 'pie',
                data: {
                    labels: complexity.map(c => c.loi_nom),
                    datasets: [{
                        data: complexity.map(c => c.scenario_count),
                        backgroundColor: lawColors
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    plugins: {
                        legend: { position: 'bottom' }
                    }
                }
            });
        }

        // Law success chart
        if (success && success.length > 0) {
            const ctx = document.getElementById('lawSuccessChart').getContext('2d');
            if (charts.lawSuccessChart) charts.lawSuccessChart.destroy();
            
            charts.lawSuccessChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: success.map(s => s.loi_nom),
                    datasets: [{
                        label: 'Taux de Réussite (%)',
                        data: success.map(s => s.pourcent_succes),
                        backgroundColor: lawColors,
                        borderColor: lawColors,
                        borderWidth: 2
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    scales: {
                        y: { beginAtZero: true, max: 100 }
                    }
                }
            });
        }

        // Ethical scenarios table
        const scenarios = await fetch('/api/ethical-dilemmas').then(r => r.json());
        if (scenarios && scenarios.length > 0) {
            const tbody = document.getElementById('ethicalTableBody');
            tbody.innerHTML = scenarios.slice(0, 10).map((s, i) => `
                <tr>
                    <td>${s.description}</td>
                    <td>Loi ${s.loi}</td>
                    <td>${s.times_faced}</td>
                    <td>${s.succes || 0}</td>
                    <td>${s.taux_reussite || 0}%</td>
                </tr>
            `).join('');
        }

    } catch (error) {
        console.error('Error loading ethics tab:', error);
    }
}

// ============================================================================
// TAB: ROBOTS
// ============================================================================

async function loadRobotsTab() {
    try {
        const perf = await fetch('/api/performance-by-model').then(r => r.json());
        
        if (perf && perf.length > 0) {
            const ctx = document.getElementById('robotComparisonChart').getContext('2d');
            if (charts.robotComparisonChart) charts.robotComparisonChart.destroy();
            
            charts.robotComparisonChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: perf.map(p => p.modele),
                    datasets: [
                        {
                            label: 'Succès',
                            data: perf.map(p => p.succes),
                            backgroundColor: '#00ff64'
                        },
                        {
                            label: 'Mitigé',
                            data: perf.map(p => p.mitiges),
                            backgroundColor: '#ffa500'
                        },
                        {
                            label: 'Échec',
                            data: perf.map(p => p.echecs),
                            backgroundColor: '#ff4444'
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    scales: {
                        x: { stacked: false },
                        y: { stacked: false }
                    }
                }
            });
        }

        // Robot rankings table
        const robots = await fetch('/api/robot-specialization').then(r => r.json());
        if (robots && robots.length > 0) {
            const tbody = document.getElementById('robotRankingsBody');
            tbody.innerHTML = robots.map((r, i) => `
                <tr>
                    <td>${i + 1}</td>
                    <td>${r.nom_robot}</td>
                    <td>${r.modele}</td>
                    <td>${r.etat}</td>
                    <td>${r.actions_totales || 0}</td>
                    <td>${r.scenarios_traites || 0}</td>
                    <td>${r.succes || 0}</td>
                    <td>${r.taux_reussite || 0}%</td>
                </tr>
            `).join('');
        }

    } catch (error) {
        console.error('Error loading robots tab:', error);
    }
}

// ============================================================================
// TAB: VULNERABILITY
// ============================================================================

async function loadVulnerabilityTab() {
    try {
        const impact = await fetch('/api/vulnerability-impact').then(r => r.json());
        
        if (impact && impact.length > 0) {
            const ctx = document.getElementById('vulnerabilityOutcomesChart').getContext('2d');
            if (charts.vulnerabilityOutcomesChart) charts.vulnerabilityOutcomesChart.destroy();
            
            charts.vulnerabilityOutcomesChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: impact.map(i => i.vulnerabilite),
                    datasets: [
                        {
                            label: 'Succès',
                            data: impact.map(i => i.succes),
                            backgroundColor: '#00ff64'
                        },
                        {
                            label: 'Mitigé',
                            data: impact.map(i => i.mitiges),
                            backgroundColor: '#ffa500'
                        },
                        {
                            label: 'Échec',
                            data: impact.map(i => i.echecs),
                            backgroundColor: '#ff4444'
                        }
                    ]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    indexAxis: 'y'
                }
            });
        }

        // Sector analysis table
        const sectors = await fetch('/api/sector-ethical-analysis').then(r => r.json());
        if (sectors && sectors.length > 0) {
            const tbody = document.getElementById('sectorAnalysisBody');
            tbody.innerHTML = sectors.map(s => `
                <tr>
                    <td>${s.secteur}</td>
                    <td>${s.scenarios_distincts || 0}</td>
                    <td>${s.total_actions || 0}</td>
                    <td>${s.succes || 0}</td>
                    <td>${s.echecs || 0}</td>
                    <td>${s.taux_reussite}%</td>
                </tr>
            `).join('');
        }

    } catch (error) {
        console.error('Error loading vulnerability tab:', error);
    }
}

// ============================================================================
// TAB: ACTIONS
// ============================================================================

async function loadActionsTab() {
    try {
        const categories = await fetch('/api/action-categories').then(r => r.json());
        
        if (categories && categories.length > 0) {
            const ctx = document.getElementById('actionCategoriesChart').getContext('2d');
            if (charts.actionCategoriesChart) charts.actionCategoriesChart.destroy();
            
            charts.actionCategoriesChart = new Chart(ctx, {
                type: 'bar',
                data: {
                    labels: categories.map(c => c.categorie),
                    datasets: [{
                        label: 'Taux de Réussite (%)',
                        data: categories.map(c => c.taux_reussite),
                        backgroundColor: categories.map(c => {
                            const rate = c.taux_reussite || 0;
                            if (rate >= 75) return '#00ff64';
                            if (rate >= 50) return '#ffd93d';
                            return '#ff4444';
                        })
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: true,
                    indexAxis: 'y',
                    scales: {
                        x: { beginAtZero: true, max: 100 }
                    }
                }
            });

            // Action categories table
            const tbody = document.getElementById('actionCategoriesBody');
            tbody.innerHTML = categories.map(c => `
                <tr>
                    <td>${c.categorie}</td>
                    <td>${c.total}</td>
                    <td>${c.succes}</td>
                    <td>${c.taux_reussite}%</td>
                    <td>${c.taux_reussite >= 75 ? '✅' : (c.taux_reussite >= 50 ? '⚠️' : '❌')}</td>
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
        const timeline = await fetch('/api/timeline').then(r => r.json());
        
        if (timeline && timeline.length > 0) {
            const list = document.getElementById('timelineList');
            list.innerHTML = timeline.slice(0, 20).map(t => `
                <div class="timeline-item">
                    <div class="timeline-time">${t.timestamp ? new Date(t.timestamp).toLocaleString('fr-FR') : '-'}</div>
                    <div class="timeline-content">
                        <div class="timeline-action">${t.action}</div>
                        <div class="timeline-details">
                            <span>Robot: ${t.nom_robot || 'N/A'}</span>
                            <span>Humain: ${t.nom || 'N/A'}</span>
                            <span>Résultat: <strong class="result-${t.resultat}">${t.resultat}</strong></span>
                        </div>
                        <div class="timeline-scenario">${t.description || 'Scénario non spécifié'}</div>
                    </div>
                </div>
            `).join('');
        }

    } catch (error) {
        console.error('Error loading timeline:', error);
    }
}
