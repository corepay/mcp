const KanbanHook = {
  mounted() {
    this.el.addEventListener("dragstart", (e) => {
      e.dataTransfer.effectAllowed = "move";
      e.dataTransfer.setData("text/plain", e.target.dataset.id);
      e.target.classList.add("opacity-50");
    });

    this.el.addEventListener("dragend", (e) => {
      e.target.classList.remove("opacity-50");
    });

    this.el.addEventListener("dragover", (e) => {
      e.preventDefault();
      e.dataTransfer.dropEffect = "move";
      this.el.classList.add("bg-slate-700/50");
    });

    this.el.addEventListener("dragleave", (e) => {
      this.el.classList.remove("bg-slate-700/50");
    });

    this.el.addEventListener("drop", (e) => {
      e.preventDefault();
      this.el.classList.remove("bg-slate-700/50");
      
      const id = e.dataTransfer.getData("text/plain");
      const newStatus = this.el.dataset.status;
      
      if (id && newStatus) {
        this.pushEvent("update_status", { id: id, new_status: newStatus });
      }
    });
  }
};

export default KanbanHook;
