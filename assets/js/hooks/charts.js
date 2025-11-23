/**
 * Chart.js hooks for analytics dashboard widgets.
 *
 * Provides various chart types including line charts, bar charts,
 * pie charts, gauges, heatmaps, and ISP-specific visualizations.
 */

import Chart from 'chart.js/auto';
import 'chartjs-adapter-date-fns';

// Line Chart Hook
const LineChart = {
  mounted() {
    const canvas = this.el;
    const ctx = canvas.getContext('2d');
    const data = JSON.parse(canvas.dataset.chartData || '{}');

    this.chart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: data.labels || [],
        datasets: (data.datasets || []).map(dataset => ({
          label: dataset.label || 'Metric',
          data: dataset.data || [],
          borderColor: dataset.color || '#3b82f6',
          backgroundColor: dataset.backgroundColor || 'rgba(59, 130, 246, 0.1)',
          tension: 0.4,
          fill: true
        }))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: (data.datasets || []).length > 1
          },
          tooltip: {
            mode: 'index',
            intersect: false
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(156, 163, 175, 0.1)'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        },
        interaction: {
          mode: 'nearest',
          axis: 'x',
          intersect: false
        }
      }
    });

    // Handle updates
    this.handleEvent(`chart:update:${canvas.id}`, ({ data }) => {
      this.chart.data = data;
      this.chart.update();
    });
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

// Bar Chart Hook
const BarChart = {
  mounted() {
    const canvas = this.el;
    const ctx = canvas.getContext('2d');
    const data = JSON.parse(canvas.dataset.chartData || '{}');

    this.chart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: data.labels || [],
        datasets: (data.datasets || []).map(dataset => ({
          label: dataset.label || 'Metric',
          data: dataset.data || [],
          backgroundColor: dataset.backgroundColor || ['#3b82f6', '#10b981', '#f59e0b', '#ef4444'],
          borderColor: dataset.borderColor || ['#2563eb', '#059669', '#d97706', '#dc2626'],
          borderWidth: 1
        }))
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: (data.datasets || []).length > 1
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            grid: {
              color: 'rgba(156, 163, 175, 0.1)'
            }
          },
          x: {
            grid: {
              display: false
            }
          }
        }
      }
    });
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

// Pie Chart Hook
const PieChart = {
  mounted() {
    const canvas = this.el;
    const ctx = canvas.getContext('2d');
    const data = JSON.parse(canvas.dataset.chartData || '{}');

    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: data.labels || [],
        datasets: [{
          data: data.values || [],
          backgroundColor: [
            '#3b82f6', '#10b981', '#f59e0b', '#ef4444',
            '#8b5cf6', '#ec4899', '#14b8a6', '#f97316'
          ],
          borderWidth: 2,
          borderColor: '#ffffff'
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'bottom'
          }
        }
      }
    });
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

// Heatmap Hook
const Heatmap = {
  mounted() {
    const canvas = this.el;
    const ctx = canvas.getContext('2d');
    const data = JSON.parse(canvas.dataset.chartData || '{}');

    this.renderHeatmap(ctx, data);
  },

  renderHeatmap(ctx, data) {
    const { values, labels, xAxisLabels, yAxisLabels } = data;
    const width = ctx.canvas.width;
    const height = ctx.canvas.height;
    const cellWidth = width / (xAxisLabels?.length || values[0]?.length || 1);
    const cellHeight = height / (yAxisLabels?.length || values.length || 1);

    // Clear canvas
    ctx.clearRect(0, 0, width, height);

    // Draw heatmap cells
    values.forEach((row, i) => {
      row.forEach((value, j) => {
        const color = this.getHeatmapColor(value);
        ctx.fillStyle = color;
        ctx.fillRect(j * cellWidth, i * cellHeight, cellWidth, cellHeight);

        // Add cell border
        ctx.strokeStyle = 'rgba(156, 163, 175, 0.3)';
        ctx.strokeRect(j * cellWidth, i * cellHeight, cellWidth, cellHeight);
      });
    });
  },

  getHeatmapColor(value) {
    // Simple blue to red gradient
    const intensity = Math.min(Math.max(value, 0), 1);
    const r = Math.round(255 * intensity);
    const b = Math.round(255 * (1 - intensity));
    return `rgb(${r}, 100, ${b})`;
  }
};

// Network Map Hook for ISP topology
const NetworkMap = {
  mounted() {
    const container = this.el;
    const data = JSON.parse(container.dataset.mapData || '{}');

    this.initializeNetworkMap(container, data);
  },

  initializeNetworkMap(container, data) {
    // Simple network map visualization using D3-like approach
    const { nodes, connections } = data;

    if (!nodes || nodes.length === 0) {
      container.innerHTML = `
        <div class="flex items-center justify-center h-full text-base-content/60">
          <div class="text-center">
            <svg class="w-16 h-16 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M9 20l-5.447-2.724A1 1 0 013 16.382V5.618a1 1 0 011.447-.894L9 7m0 13l6-3m-6 3V7m6 10l4.553 2.276A1 1 0 0021 18.382V7.618a1 1 0 00-.553-.894L15 4m0 13V4m0 0L9 7"/>
            </svg>
            Network Map
          </div>
        </div>
      `;
      return;
    }

    // Create network topology
    container.innerHTML = `
      <div class="relative h-full p-4">
        <div class="network-nodes">
          ${nodes.map(node => `
            <div class="network-node absolute transform -translate-x-1/2 -translate-y-1/2"
                 style="left: ${node.x}%; top: ${node.y}%;">
              <div class="relative">
                <div class="w-8 h-8 ${node.type === 'router' ? 'bg-primary' : 'bg-secondary'}
                            rounded-full flex items-center justify-center text-white text-xs font-bold">
                  ${node.name.charAt(0)}
                </div>
                <div class="absolute -bottom-6 left-1/2 transform -translate-x-1/2
                           text-xs whitespace-nowrap">
                  ${node.name}
                </div>
              </div>
            </div>
          `).join('')}
        </div>
        <svg class="absolute inset-0 pointer-events-none" style="z-index: -1;">
          ${connections.map(conn => `
            <line x1="${conn.from.x}%" y1="${conn.from.y}%"
                  x2="${conn.to.x}%" y2="${conn.to.y}%"
                  stroke="${conn.status === 'online' ? '#10b981' : '#ef4444'}"
                  stroke-width="2"
                  stroke-dasharray="${conn.status === 'online' ? '0' : '5,5'}"/>
          `).join('')}
        </svg>
      </div>
    `;
  }
};

// ISP Bandwidth Monitor Hook
const BandwidthMonitor = {
  mounted() {
    const container = this.el;
    const data = JSON.parse(container.dataset.bandwidthData || '{}');

    this.initializeBandwidthMonitor(container, data);
  },

  initializeBandwidthMonitor(container, data) {
    container.innerHTML = `
      <div class="h-full flex flex-col justify-between">
        <div class="text-center mb-4">
          <div class="text-3xl font-bold text-primary">
            ${this.formatBytes(data.current_bandwidth || 0)}/s
          </div>
          <div class="text-sm text-base-content/60">Current Usage</div>
        </div>

        <div class="flex-1 relative">
          <canvas id="bandwidth-chart-${container.id}" class="w-full h-full"></canvas>
        </div>

        <div class="mt-4 grid grid-cols-2 gap-4 text-xs">
          <div>
            <span class="text-base-content/60">Peak: </span>
            <span class="font-semibold">${this.formatBytes(data.peak_bandwidth || 0)}/s</span>
          </div>
          <div>
            <span class="text-base-content/60">Average: </span>
            <span class="font-semibold">${this.formatBytes(data.average_bandwidth || 0)}/s</span>
          </div>
        </div>
      </div>
    `;

    // Create real-time bandwidth chart
    const canvas = container.querySelector(`#bandwidth-chart-${container.id}`);
    const ctx = canvas.getContext('2d');

    this.bandwidthChart = new Chart(ctx, {
      type: 'line',
      data: {
        labels: Array.from({length: 60}, (_, i) => `${60-i}s`),
        datasets: [{
          label: 'Bandwidth',
          data: Array(60).fill(0),
          borderColor: '#3b82f6',
          backgroundColor: 'rgba(59, 130, 246, 0.1)',
          tension: 0.4,
          fill: true
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: (value) => this.formatBytes(value)
            }
          }
        }
      }
    });

    // Subscribe to real-time updates
    this.handleEvent(`bandwidth:update:${container.id}`, ({ bandwidth }) => {
      this.bandwidthChart.data.datasets[0].data.shift();
      this.bandwidthChart.data.datasets[0].data.push(bandwidth);
      this.bandwidthChart.update('none');
    });
  },

  formatBytes(bytes) {
    if (!bytes || bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
  },

  destroyed() {
    if (this.bandwidthChart) {
      this.bandwidthChart.destroy();
    }
  }
};

// Service Status Monitor Hook
const ServiceStatusMonitor = {
  mounted() {
    const container = this.el;
    const data = JSON.parse(container.dataset.serviceData || '{}');

    this.renderServiceStatus(container, data);
  },

  renderServiceStatus(container, data) {
    const services = data.services || [];

    container.innerHTML = `
      <div class="space-y-2">
        ${services.map(service => `
          <div class="p-3 bg-base-100 rounded-lg border border-base-300">
            <div class="flex items-center justify-between">
              <div class="flex items-center gap-3">
                <div class="w-2 h-2 rounded-full ${this.getStatusColor(service.status)}"></div>
                <div>
                  <div class="font-medium text-sm">${service.name}</div>
                  ${service.description ?
                    `<div class="text-xs text-base-content/60">${service.description}</div>` : ''}
                </div>
              </div>
              <div class="text-right">
                <div class="text-xs font-medium ${this.getStatusTextColor(service.status)}">
                  ${service.status.toUpperCase()}
                </div>
                ${service.response_time ?
                  `<div class="text-xs text-base-content/60">${service.response_time}ms</div>` : ''}
              </div>
            </div>
            ${service.uptime !== undefined ? `
              <div class="mt-2">
                <div class="flex items-center justify-between text-xs text-base-content/60 mb-1">
                  <span>Uptime</span>
                  <span>${service.uptime}%</span>
                </div>
                <div class="progress w-full h-1 bg-base-200">
                  <div class="progress-bar ${this.getUptimeBarColor(service.uptime)}"
                       style="width: ${service.uptime}%"></div>
                </div>
              </div>
            ` : ''}
          </div>
        `).join('')}
      </div>
    `;
  },

  getStatusColor(status) {
    switch (status.toLowerCase()) {
      case 'online': return 'bg-success';
      case 'degraded': return 'bg-warning';
      case 'offline': return 'bg-error';
      default: return 'bg-neutral';
    }
  },

  getStatusTextColor(status) {
    switch (status.toLowerCase()) {
      case 'online': return 'text-success';
      case 'degraded': return 'text-warning';
      case 'offline': return 'text-error';
      default: return 'text-neutral';
    }
  },

  getUptimeBarColor(uptime) {
    if (uptime >= 99) return 'bg-success';
    if (uptime >= 95) return 'bg-warning';
    return 'bg-error';
  }
};

// Export hooks for use in Phoenix LiveView
export default {
  LineChart,
  BarChart,
  PieChart,
  Heatmap,
  NetworkMap,
  BandwidthMonitor,
  ServiceStatusMonitor
};