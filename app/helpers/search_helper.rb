module SearchHelper
  def link_for_reference(reference)
    case reference.class
    when Chunk
      collection_document_chunk_path(reference.collection, reference.document, reference)
    else
      "/404"
    end
  end
end
