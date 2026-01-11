/**
 * Sortable hook for drag-and-drop reordering of list items.
 * Sends "reorder" event with {from, to} indices.
 */
const SortableHook = {
  mounted() {
    this.dragged = null;
    this.draggedIndex = null;

    // Make rows draggable
    this.el.querySelectorAll("tr[data-id]").forEach((row, index) => {
      row.draggable = true;
      row.dataset.index = index;
    });

    this.el.addEventListener("dragstart", (e) => {
      const row = e.target.closest("tr[data-id]");
      if (!row) return;

      this.dragged = row;
      this.draggedIndex = parseInt(row.dataset.index, 10);
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", row.dataset.id);
      row.classList.add("opacity-50");
    });

    this.el.addEventListener("dragend", (e) => {
      const row = e.target.closest("tr[data-id]");
      if (row) {
        row.classList.remove("opacity-50");
      }
      this.dragged = null;
      this.draggedIndex = null;
    });

    this.el.addEventListener("dragover", (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";

      const row = e.target.closest("tr[data-id]");
      if (row && row !== this.dragged) {
        row.classList.add("bg-base-200");
      }
    });

    this.el.addEventListener("dragleave", (e) => {
      const row = e.target.closest("tr[data-id]");
      if (row) {
        row.classList.remove("bg-base-200");
      }
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();

      const targetRow = e.target.closest("tr[data-id]");
      if (!targetRow || !this.dragged || targetRow === this.dragged) {
        return;
      }

      targetRow.classList.remove("bg-base-200");

      const targetIndex = parseInt(targetRow.dataset.index, 10);

      if (this.draggedIndex !== null && targetIndex !== this.draggedIndex) {
        this.pushEvent("reorder", { from: this.draggedIndex, to: targetIndex });
      }
    });
  },

  updated() {
    // Re-apply draggable and index after DOM updates
    this.el.querySelectorAll("tr[data-id]").forEach((row, index) => {
      row.draggable = true;
      row.dataset.index = index;
    });
  }
};

export default SortableHook;
