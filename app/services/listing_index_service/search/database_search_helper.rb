module ListingIndexService::Search::DatabaseSearchHelper

  module_function

  def success_result(count, listings, includes, distances = {})
    converted_listings = listings.map do |listing|
      distance_hash = distances[listing.id] || {}
      ListingIndexService::Search::Converters.listing_hash(listing, includes, distance_hash)
    end
    Result::Success.new({count: count, listings: converted_listings})
  end

  def fetch_from_db(community_id:, search:, included_models:, includes:)
    where_opts = HashUtils.compact(
      {
        community_id: community_id,
        author_id: search[:author_id],
        deleted: 0,
        listing_shape_id: Maybe(search[:listing_shape_ids]).or_else(nil)
      })

     
      community = Community.find_by(id: community_id)
      # if community[:IsListingApprovalRequired] == true
      #   where_opts[:is_approved] = 1
      # end

    query = Listing
            .where(where_opts)
            .includes(included_models)
            .order("listings.sort_date DESC")
            .paginate(per_page: search[:per_page], page: search[:page])

    listings =
      if search[:include_closed]
        query
      else
        query.currently_open
      end

    success_result(listings.total_entries, listings, includes)
  end

  # TODO: This should probably be rethought when the Indexer and the
  # new Search API is finished and in use
  def needs_db_query?(search)
    search[:author_id].present? || search[:include_closed] == true
  end

  def needs_search?(search)
    [
      :keywords,
      :latitude,
      :longitude,
      :distance_max,
      :sort,
      :listing_shape_id,
      :categories,
      :fields,
      :price_cents
    ].any? { |field| search[field].present? }
  end

end
