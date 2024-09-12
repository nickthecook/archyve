module SearchHelper
  def link_for_reference(reference)
    if reference.instance_of?(Chunk)
      collection_document_chunk_path(reference.collection, reference.document, reference)
    elsif reference.instance_of?(GraphEntity)
      collection_entity_path(reference.collection, reference)
    else
      "/404"
    end
  end
end
