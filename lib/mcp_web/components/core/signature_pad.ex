defmodule McpWeb.CoreComponents.SignaturePad do
  use Phoenix.Component

  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, default: "Signature"
  attr :class, :string, default: nil

  def signature_pad(assigns) do
    ~H"""
    <div class={["form-control w-full", @class]}>
      <label class="label">
        <span class="label-text"><%= @label %></span>
      </label>
      <div 
        id={@id} 
        phx-hook="SignaturePad" 
        class="border-2 border-dashed border-base-300 rounded-lg bg-base-100 relative"
      >
        <canvas 
          class="w-full h-40 cursor-crosshair touch-none"
          width="600"
          height="200"
        ></canvas>
        
        <input type="hidden" name={@name} id={"#{@id}-input"} />
        
        <div class="absolute bottom-2 right-2 flex gap-2">
          <label class="btn btn-xs btn-ghost text-primary cursor-pointer">
            Upload
            <input type="file" class="hidden" accept="image/*" data-action="upload" />
          </label>
          <button type="button" class="btn btn-xs btn-ghost text-error" data-action="clear">
            Clear
          </button>
        </div>
        
        <div class="absolute inset-0 flex items-center justify-center pointer-events-none opacity-10">
          <span class="text-4xl font-handwriting">Sign Here</span>
        </div>
      </div>
      <label class="label">
        <span class="label-text-alt">Please sign within the box above.</span>
      </label>
    </div>
    """
  end
end
