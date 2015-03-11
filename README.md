# Design

This plugin will work in the same basic way as the [Solr Pro Plugin]:

- config for general settings
- a content type with records for each indexed type, and settings to
  configure property weighting
- an event handler that triggers index updates on save and delete
- a library in the application scope that encapsulates searches
  and index updates

For references, these features will not be implemented at this time:

- a default search form / interface (that will need to be implemented 
  in the project)
- document boosting / search
- search term highlighting
- autocomplete / suggestions
- facets
- document content

Notes about [CloudSearch] architecture:

- index configs (i.e. fields, field types, weighting) are pre-defined 
  in CloudSearch
- after changing index configs, a re-index must be requested
- changing index configs can potentially cause FailedToValidate errors 
  on document fields (usually if the field type has changed)during the 
  next index, and indexing will fail until the offending documents are 
  updated

Approach:

1. CloudSearch initialization, discovery, and basic troubleshooting tools,
   i.e. are we connected, how many documents are there ~1d
   DONE
2. Basic configuration for type indexes, suitable for dmHTML for example
3. Manual index updates; webtop overview tab that shows what would be sent
   to CloudSearch / is in CloudSearch
4. Search tool in webtop for troubleshooting
5. Handling of FailedToValidate, i.e. re-uploading problem documents
6. Automatic index updates on save / delete
7. Bulk update function for 
   - new indexes
   - changed index configs, i.e. adding properties to index

[Solr Pro Plugin]: https://github.com/jeffcoughlin/farcrysolrpro
[CloudSearch]: http://docs.aws.amazon.com/cloudsearch/latest/developerguide/what-is-cloudsearch.html