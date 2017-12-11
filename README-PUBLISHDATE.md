# AWS Cloudsearch Plugin - Publish Date

If indexed content types have a 'Publish Date' they will need to be filtered out of the search results so they are not displayed on the web site.

To do this, when calling application.fc.lib.cloudsearch.search(), pass to filter argument an array that includes the property. E.g.
```
// CloudSearch filters
// publish status & publication date
    arrayAppend(aFilters, 
        {
            "property": "status",
            "term" : "approved"
        }
    );
    arrayAppend(aFilters, 
        {
            "property": "publishdate",
            "dateafter" : "#Now()#"
        }
    );
```
Sample search form with search function:
<https://bitbucket.org/daemonite/yaffa-env-dsp/src/bafe05e36890b0c0259e4b72e7faadb0eaff7656/project/webskin/configCloudSearch/displayBodySearch.cfm?at=feature%2Fcloudsearch-update&fileviewer=file-view-default>


There may be content types that do not have a Publish Date property. In this case, the project will need some additions.

Extend ‘farcry.plugins.cloudsearch.packages.types.csContentType’ to add functions getGeneratedProperties() and getCloudsearchDocument().
<https://bitbucket.org/daemonite/yaffa-env-dsp/src/bafe05e36890b0c0259e4b72e7faadb0eaff7656/project/packages/types/csContentType.cfc?at=feature%2Fcloudsearch-update&fileviewer=file-view-default>

For each content Type that does not have a ‘publishDate’ property, add function getCloudsearchPublishDate()
```
<cffunction name="getCloudsearchPublishDate" access="public" output="false" returntype="date" hint="AWS CloudSearch helper">
    <cfreturn application.fc.lib.cloudsearch.getRFC3339Date(ARGUMENTS.stObject.DATETIMECREATED)>
</cffunction>
```

NOTE: for dmFile, use ‘documentDate’
