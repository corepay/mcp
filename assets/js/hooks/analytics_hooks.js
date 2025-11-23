// Analytics LiveView hooks for data visualization

export const LineChartHook = {
  mounted() {
    const chartData = JSON.parse(this.el.dataset.chartData || '[]');
    const config = JSON.parse(this.el.dataset.config || '{}');

    this.initChart(chartData, config);

    // Listen for chart updates
    this.handleEvent("update_chart", ({ widget_id, data }) => {
      if (this.el.id.includes(widget_id)) {
        this.updateChart(data);
      }
    });
  },

  updated() {
    const chartData = JSON.parse(this.el.dataset.chartData || '[]');
    const config = JSON.parse(this.el.dataset.config || '{}');
    this.updateChart(chartData);
  },

  initChart(data, config) {
    // Check if Chart.js is available
    if (typeof Chart === 'undefined') {
      console.error('Chart.js not loaded');
      return;
    }

    const ctx = this.el.getContext('2d');

    const chartConfig = {
      type: 'line',
      data: {
        labels: data.map(item => new Date(item.timestamp).toLocaleTimeString()),
        datasets: [{
          label: config.title || 'Metric',
          data: data.map(item => item.value),
          borderColor: config.color || 'rgb(59, 130, 246)',
          backgroundColor: config.backgroundColor || 'rgba(59, 130, 246, 0.1)',
          borderWidth: 2,
          fill: config.fill || false,
          tension: 0.1
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: config.showLegend || false
          },
          tooltip: {
            mode: 'index',
            intersect: false,
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.parsed.y.toFixed(2)}`;
              }
            }
          }
        },
        scales: {
          x: {
            type: 'time',
            time: {
              displayFormats: {
                minute: 'HH:mm',
                hour: 'HH:mm',
                day: 'MMM dd'
              }
            },
            grid: {
              display: config.showGrid || true
            }
          },
          y: {
            beginAtZero: config.beginAtZero || false,
            grid: {
              display: config.showGrid || true
            },
            ticks: {
              callback: function(value) {
                if (config.format === 'percentage') {
                  return value + '%';
                } else if (config.format === 'currency') {
                  return '$' + value.toLocaleString();
                }
                return value.toLocaleString();
              }
            }
          }
        }
      }
    };

    this.chart = new Chart(ctx, chartConfig);
  },

  updateChart(newData) {
    if (!this.chart) return;

    this.chart.data.labels = newData.map(item => new Date(item.timestamp).toLocaleTimeString());
    this.chart.data.datasets[0].data = newData.map(item => item.value);
    this.chart.update('none'); // Update without animation for performance
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export const BarChartHook = {
  mounted() {
    const chartData = JSON.parse(this.el.dataset.chartData || '{}');
    const config = JSON.parse(this.el.dataset.config || '{}');

    this.initChart(chartData, config);
  },

  updated() {
    const chartData = JSON.parse(this.el.dataset.chartData || '{}');
    this.updateChart(chartData);
  },

  initChart(data, config) {
    if (typeof Chart === 'undefined') {
      console.error('Chart.js not loaded');
      return;
    }

    const ctx = this.el.getContext('2d');

    const datasets = config.categories || ['default'];
    const chartDatasets = datasets.map((category, index) => ({
      label: category,
      data: data.series?.find(s => s.name === category)?.data || [],
      backgroundColor: config.colors?.[index] || `hsl(${index * 60}, 70%, 50%)`,
      borderWidth: 0
    }));

    const chartConfig = {
      type: 'bar',
      data: {
        labels: data.labels || [],
        datasets: chartDatasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: datasets.length > 1
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return `${context.dataset.label}: ${context.parsed.y.toFixed(2)}`;
              }
            }
          }
        },
        scales: {
          x: {
            grid: {
              display: false
            }
          },
          y: {
            beginAtZero: true,
            ticks: {
              callback: function(value) {
                if (config.format === 'percentage') {
                  return value + '%';
                } else if (config.format === 'currency') {
                  return '$' + value.toLocaleString();
                }
                return value.toLocaleString();
              }
            }
          }
        }
      }
    };

    this.chart = new Chart(ctx, chartConfig);
  },

  updateChart(newData) {
    if (!this.chart) return;

    this.chart.data.labels = newData.labels || [];
    this.chart.data.datasets.forEach((dataset, index) => {
      const seriesData = newData.series?.find(s => s.name === dataset.label);
      if (seriesData) {
        dataset.data = seriesData.data.map(point => point.y);
      }
    });
    this.chart.update('none');
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export const PieChartHook = {
  mounted() {
    const chartData = JSON.parse(this.el.dataset.chartData || '{}');
    const config = JSON.parse(this.el.dataset.config || '{}');

    this.initChart(chartData, config);
  },

  updated() {
    const chartData = JSON.parse(this.el.dataset.chartData || '{}');
    this.updateChart(chartData);
  },

  initChart(data, config) {
    if (typeof Chart === 'undefined') {
      console.error('Chart.js not loaded');
      return;
    }

    const ctx = this.el.getContext('2d');

    // Convert data to pie chart format
    const labels = Object.keys(data);
    const values = Object.values(data);

    const chartConfig = {
      type: 'pie',
      data: {
        labels: labels,
        datasets: [{
          data: values,
          backgroundColor: config.colors || [
            '#3B82F6', '#EF4444', '#10B981', '#F59E0B',
            '#8B5CF6', '#F97316', '#EC4899', '#6366F1'
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
            position: config.legendPosition || 'right'
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((context.parsed / total) * 100).toFixed(1);
                return `${context.label}: ${context.parsed} (${percentage}%)`;
              }
            }
          }
        }
      }
    };

    this.chart = new Chart(ctx, chartConfig);
  },

  updateChart(newData) {
    if (!this.chart) return;

    const labels = Object.keys(newData);
    const values = Object.values(newData);

    this.chart.data.labels = labels;
    this.chart.data.datasets[0].data = values;
    this.chart.update('none');
  },

  destroyed() {
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

export const WidgetHook = {
  mounted() {
    const widgetId = this.el.dataset.widgetId;
    const widgetType = this.el.dataset.widgetType;

    // Initialize widget-specific functionality
    this.setupWidget(widgetType);

    // Listen for real-time updates
    this.handleEvent(`widget_update:${widgetId}`, ({ data }) => {
      this.updateWidget(data);
    });

    // Setup resize observer for responsive charts
    if (['line_chart', 'bar_chart', 'pie_chart'].includes(widgetType)) {
      this.setupResizeObserver();
    }
  },

  setupWidget(type) {
    switch (type) {
      case 'line_chart':
      case 'bar_chart':
      case 'pie_chart':
        // Chart widgets are handled by specific hooks
        break;

      case 'number_card':
        this.setupNumberCard();
        break;

      case 'table':
        this.setupTable();
        break;

      case 'gauge':
        this.setupGauge();
        break;
    }
  },

  setupNumberCard() {
    // Add animation for number changes
    const valueElement = this.el.querySelector('.text-3xl');
    if (valueElement) {
      this.observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === 'childList' || mutation.type === 'characterData') {
            this.animateValue(valueElement);
          }
        });
      });

      this.observer.observe(valueElement, {
        childList: true,
        characterData: true,
        subtree: true
      });
    }
  },

  animateValue(element) {
    const finalValue = parseFloat(element.textContent.replace(/[^0-9.-]/g, ''));
    const duration = 500;
    const start = performance.now();
    const startValue = this.lastValue || 0;

    const animate = (currentTime) => {
      const elapsed = currentTime - start;
      const progress = Math.min(elapsed / duration, 1);

      const currentValue = startValue + (finalValue - startValue) * this.easeOutCubic(progress);

      // Format the number based on the original format
      const format = element.dataset.format || 'number';
      element.textContent = this.formatNumber(currentValue, format);

      if (progress < 1) {
        requestAnimationFrame(animate);
      } else {
        this.lastValue = finalValue;
      }
    };

    requestAnimationFrame(animate);
  },

  easeOutCubic(t) {
    return 1 - Math.pow(1 - t, 3);
  },

  formatNumber(value, format) {
    switch (format) {
      case 'currency':
        return '$' + value.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      case 'percentage':
        return value.toFixed(1) + '%';
      case 'bytes':
        return this.formatBytes(value);
      default:
        return Math.round(value).toLocaleString();
    }
  },

  formatBytes(bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes === 0) return '0 B';
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
  },

  setupTable() {
    // Add sorting functionality
    const table = this.el.querySelector('table');
    if (table) {
      const headers = table.querySelectorAll('th');
      headers.forEach((header, index) => {
        header.style.cursor = 'pointer';
        header.addEventListener('click', () => {
          this.sortTable(table, index);
        });
      });
    }
  },

  sortTable(table, columnIndex) {
    const tbody = table.querySelector('tbody');
    const rows = Array.from(tbody.querySelectorAll('tr'));

    const sortedRows = rows.sort((a, b) => {
      const aValue = a.cells[columnIndex].textContent.trim();
      const bValue = b.cells[columnIndex].textContent.trim();

      // Try to parse as number
      const aNum = parseFloat(aValue);
      const bNum = parseFloat(bValue);

      if (!isNaN(aNum) && !isNaN(bNum)) {
        return aNum - bNum;
      }

      return aValue.localeCompare(bValue);
    });

    // Clear and re-append sorted rows
    tbody.innerHTML = '';
    sortedRows.forEach(row => tbody.appendChild(row));
  },

  setupGauge() {
    // Add interactive gauge functionality
    const gauge = this.el.querySelector('svg');
    if (gauge) {
      gauge.addEventListener('click', () => {
        this.pushEvent("drill_down", {
          widget_id: this.el.dataset.widgetId,
          metric: "gauge_value"
        });
      });
    }
  },

  setupResizeObserver() {
    this.resizeObserver = new ResizeObserver(() => {
      // Trigger chart resize
      if (this.chart) {
        this.chart.resize();
      }
    });

    this.resizeObserver.observe(this.el);
  },

  updateWidget(data) {
    // Handle different widget data updates
    const widgetType = this.el.dataset.widgetType;

    switch (widgetType) {
      case 'number_card':
        this.updateNumberCard(data);
        break;
      case 'table':
        this.updateTable(data);
        break;
      default:
        // Charts handle their own updates via dataset attributes
        this.el.dataset.chartData = JSON.stringify(data);
        break;
    }
  },

  updateNumberCard(data) {
    const valueElement = this.el.querySelector('.text-3xl');
    const trendElement = this.el.querySelector('.text-sm');

    if (valueElement && data.current_value !== undefined) {
      valueElement.textContent = this.formatNumber(data.current_value, 'number');
    }

    if (trendElement && data.trend) {
      this.updateTrendIndicator(trendElement, data.trend);
    }
  },

  updateTrendIndicator(element, trend) {
    // Remove existing trend classes
    element.classList.remove('text-green-600', 'text-red-600', 'text-gray-600');

    switch (trend) {
      case 'up':
        element.classList.add('text-green-600');
        break;
      case 'down':
        element.classList.add('text-red-600');
        break;
      default:
        element.classList.add('text-gray-600');
    }
  },

  updateTable(data) {
    // Re-render table with new data
    const tbody = this.el.querySelector('tbody');
    if (tbody && data.rows) {
      tbody.innerHTML = '';
      data.rows.forEach(row => {
        const tr = document.createElement('tr');
        Object.values(row).forEach(cellValue => {
          const td = document.createElement('td');
          td.textContent = cellValue;
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });
    }
  },

  destroyed() {
    // Cleanup observers
    if (this.observer) {
      this.observer.disconnect();
    }
    if (this.resizeObserver) {
      this.resizeObserver.disconnect();
    }
    if (this.chart) {
      this.chart.destroy();
    }
  }
};

// Export all hooks
export default {
  LineChartHook,
  BarChartHook,
  PieChartHook,
  WidgetHook
};