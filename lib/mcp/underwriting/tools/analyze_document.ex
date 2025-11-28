defmodule Mcp.Underwriting.Tools.AnalyzeDocument do
  use Ash.Resource,
    domain: Mcp.Underwriting,
    data_layer: :embedded

  code_interface do
    define :analyze, args: [:filename, :merchant_id]
  end

  actions do
    read :analyze do
      description "Analyzes a document uploaded by the user to check for validity, blurriness, or specific content."
      argument :filename, :string, allow_nil?: false, description: "The name of the file to analyze (e.g., 'id.jpg')"
      argument :merchant_id, :uuid, allow_nil?: false, description: "The ID of the merchant the document belongs to."
      
      manual fn query, _data_layer_query, _context ->
        filename = query.arguments.filename
        merchant_id = query.arguments.merchant_id
        
        # Call the real Document Intelligence Service
        case Mcp.Underwriting.Services.DocumentIntelligence.analyze(filename, merchant_id) do
          {:ok, analysis} ->
            result = 
              if analysis.status == :completed do
                "Document analysis successful.\n\n**Markdown Content:**\n#{analysis.markdown_content}\n\n**Structured Data:**\n#{inspect(analysis.structured_data)}"
              else
                "Document analysis is pending or processing."
              end
            {:ok, [struct(Mcp.Underwriting.Tools.AnalyzeDocument, result: result)]}
            
          {:error, reason} ->
             {:error, "Document analysis failed: #{inspect(reason)}"}
        end
      end
    end
  end
  
  attributes do
    attribute :result, :string do
      public? true
    end
  end
end
