<cfsetting enablecfoutputonly="true">

<cfoutput>
	<h1>CloudSearch Status</h1>

	<h2>Configuration</h2>
	<table class="table table-striped">
		<cfloop list="domain,region,accessID,accessSecret" index="thisfield">
			<tr>
				<th>#application.stCOAPI.configCloudSearch.stProps[thisfield].metadata.ftLabel#</th>
				<td>
					<cfif len(application.fapi.getConfig("cloudsearch",thisfield,""))>
						<span class="text-green">Ok</span>
					<cfelse>
						<span class="text-red">Not ok</span>
					</cfif>
				</td>
			</tr>
		</cfloop>
	</table>
</cfoutput>

<cfif application.fc.lib.cloudsearch.isEnabled()>
	<cfset qDomains = application.fc.lib.cloudsearch.getDomains() />
	<cfset qIndexFields = application.fc.lib.cloudsearch.getIndexFields() />
	<cfset qDiffIndexFields = application.fc.lib.cloudsearch.diffIndexFields() />

	<cfif structKeyExists(url, "processingupdate")>
		<cfset aResult = []>

		<cfloop query="qDomains">
			<cfset arrayAppend(aResult, {
				"domain" = qDomains.domain,
				"processing" = qDomains.processing
			})>
		</cfloop>

		<cfloop query="qIndexFields">
			<cfset arrayAppend(aResult, {
				"field" = qIndexFields.field,
				"state" = qIndexFields.state
			})>
		</cfloop>

		<cfset application.fapi.stream(content=aResult, type="json")>
	</cfif>

	<cfoutput>
		<h2>Search Domains</h2>
		<table class="table table-striped">
			<thead>
				<tr>
					<th>Domain</th>
					<th>Created</th>
					<th>Processing Index</th>
					<th>Requires Index</th>
					<th>Deleted</th>
					<th>Instance Count</th>
					<th>Instance Type</th>
					<th></th>
				</tr>
			</thead>
			<tbody>
				<cfif not qDomains.recordcount>
					<tr class="warning"><td colspan="7">No search domains have been set up in AWS</td></tr>
				</cfif>

				<cfloop query="qDomains">
					<tr id="domain-info-#qDomains.domain#">
						<td>#qDomains.domain#</td>
						<td>#yesnoformat(qDomains.created)#</td>
						<td class="processing updatable">#yesnoformat(qDomains.processing)#</td>
						<td>#yesnoformat(qDomains.requires_index)#</td>
						<td>#yesnoformat(qDomains.deleted)#</td>
						<td>#qDomains.instance_count#</td>
						<td>#qDomains.instance_type#</td>
						<td><a class="cloudsearch-domain-action" data-confirm="Are you sure you want to re-index #qDomains.domain#?" href="#application.fapi.getLink(type='configCloudSearch',view='webtopAjaxIndexDocuments',urlParameters='domain=#qDomains.domain#')#">Index</a>
					</tr>
				</cfloop>
			</tbody>
		</table>
		<div id="cloudsearch-domain-results"></div>

		<h2>Index Fields</h2>
		<table class="table table-striped">
			<thead>
				<tr>
					<th>Field</th>
					<th>Type <a target="_blank" href="http://docs.aws.amazon.com/cloudsearch/latest/developerguide/configuring-index-fields.html"><i class="fa fa-question-o"></i></a></th>
					<th>Default</th>
					<th>Return</th>
					<th>Search</th>
					<th>Facet</th>
					<th>Sort</th>
					<th>Highlight</th>
					<th>Analysis Scheme</th>
					<th>Pending Deletion</th>
					<th>State</th>
				</tr>
			</thead>
			<tbody>
				<cfif not qIndexFields.recordcount>
					<tr class="warning"><td colspan="11">No index fields have been set up in AWS</td></tr>
				</cfif>
				
				<cfloop query="qIndexFields">
					<tr id="field-info-#qIndexFields.field#">
						<td>#qIndexFields.field#</td>
						<td>#qIndexFields.type#</td>
						<td>#qIndexFields.default_value#</td>
						<td>#yesNoFormat(qIndexFields.return)#</td>
						<td>#yesNoFormat(qIndexFields.search)#</td>
						<td>#yesNoFormat(qIndexFields.facet)#</td>
						<td>#yesNoFormat(qIndexFields.sort)#</td>
						<td>#yesNoFormat(qIndexFields.highlight)#</td>
						<td>#qIndexFields.analysis_scheme#</td>
						<td>#yesNoFormat(qIndexFields.pending_deletion)#</td>
						<td class="state updatable">#qIndexFields.state#</td>
					</tr>
				</cfloop>
			</tbody>
		</table>

		<cfif qDiffIndexFields.recordcount>
			<h2>Updates Required</h2>
			<a id="cloudsearch-apply-all" class="btn btn-primary" href="#application.fapi.getLink(type='configCloudSearch',view='webtopAjaxApplyAll')#">Apply All Updates</a>
			<table class="table table-striped">
				<thead>
					<tr>
						<th>Field</th>
						<th>Type <a target="_blank" href="http://docs.aws.amazon.com/cloudsearch/latest/developerguide/configuring-index-fields.html"><i class="fa fa-question-o"></i></a></th>
						<th>Default</th>
						<th>Return</th>
						<th>Search</th>
						<th>Facet</th>
						<th>Sort</th>
						<th>Highlight</th>
						<th>Analysis Scheme</th>
						<th>Action</th>
						<th></th>
					</tr>
				</thead>
				<tbody>
					<cfloop query="qDiffIndexFields">
						<tr>
							<td>#qDiffIndexFields.field#</td>
							<td>#qDiffIndexFields.type#</td>
							<td>#qDiffIndexFields.default_value#</td>
							<td>#yesNoFormat(qDiffIndexFields.return)#</td>
							<td>#yesNoFormat(qDiffIndexFields.search)#</td>
							<td>#yesNoFormat(qDiffIndexFields.facet)#</td>
							<td>#yesNoFormat(qDiffIndexFields.sort)#</td>
							<td>#yesNoFormat(qDiffIndexFields.highlight)#</td>
							<td>#qDiffIndexFields.analysis_scheme#</td>
							<td>#qDiffIndexFields.action#</td>
							<td>
								<cfif listFindNoCase("add,update,delete",qDiffIndexFields.action)>
									<a class="cloudsearch-field-action" href="#application.fapi.getLink(type='configCloudSearch',view='webtopAjaxApply',urlParameters='field=#qDiffIndexFields.field#')#">apply</a>
								<cfelse>
									<a class="cloudsearch-field-action" href="#application.fapi.getLink(type='configCloudSearch',view='webtopAjaxApply',urlParameters='field=#qDiffIndexFields.field#')#">refresh</a>
								</cfif>
							</td>
						</tr>
					</cfloop>
				</tbody>
			</table>
		</cfif>

		<style>
			.updatable {
				-webkit-transition: text-shadow 0.5s linear;
				-moz-transition: text-shadow 0.5s linear;
				-ms-transition: text-shadow 0.5s linear;
				-o-transition: text-shadow 0.5s linear;
				transition: text-shadow 0.5s linear;
			}
			.updatable.updated {
				text-shadow: 0 0 10px black;
			}
			.updatable.updated-yes {
				text-shadow: 0 0 10px green;
			}
			.updatable.updated-no {
				text-shadow: 0 0 10px red;
			}
		</style>
		<script type="text/javascript">
			function ajaxAction(url, confirmText, alertFn, htmlFn){

				if (confirmText && confirmText.length && !window.confirm(confirmText)){
					return;
				}

				$j.ajax({
					type : "GET",
					dataType : "json",
					url : url, 
					success : function(data){
						if (data.errors.length){
							for (var i=0; i<data.errors.length; i++){
								alertFn("error", data.errors[i].message);
							}
						}

						if (data.message.length){
							alertFn("info", data.message);
						}

						if (data.html.length){
							htmlFn(data.html);
						}
					},
					error : function(jqXHR, textStatus, errorThrown){
						var fallback = true, data = {};

						try {
							data = JSON.parse(jqXHR.responseText);
							if (data.errors.length){
								for (var i=0; i<data.errors.length; i++){
									alertFn("error", data.errors[i].message);
								}
								fallback = false;
							}
							else if (data.error){
								alertFn("error", data.error.message);
								fallback = false;
							}
						}
						catch(e){}

						if (fallback){
							if (jqXHR.status === 403) {
								alertFn("error", "Access Forbidden - your session may have timed out");
							}
							else {
								alertFn("error", errorThrown);
							}
						}
					}
				});
			}

			$j(document).on("click",".cloudsearch-domain-action", function(e){
				var self = $j(this);

				e.preventDefault();
				e.stopPropagation();

				function showAlert(status, message){
					$j("##cloudsearch-domain-results").append("<div class='alert alert-"+status+"'><button class='close' data-dismiss='alert' type='button'>×</button>"+message+"</div>");
				}
				function showHTML(html){
					showAlert("info",html);
				}

				ajaxAction(this.href, self.data("confirm"), showAlert, showHTML);

				regularProcessingCheck();
			});

			$j(document).on("click",".cloudsearch-field-action", function(e){
				var self = $j(this), tr = self.closest("tr");

				e.preventDefault();
				e.stopPropagation();

				self.closest("td").html("...");

				function showAlert(status, message){
					$j("##cloudsearch-update-results").append("<div class='alert alert-"+status+"'><button class='close' data-dismiss='alert' type='button'>×</button>"+message+"</div>");
				}
				function showHTML(html){
					tr.replaceWith(html);
				}

				ajaxAction(this.href, '', showAlert, showHTML);
			});

			$j("##cloudsearch-apply-all").on("click", function(e){
				var self = $j(this), tbody = self.closest("tbody");

				e.preventDefault();
				e.stopPropagation();

				tbody.find(".cloudsearch-field-action").closest("td").html("...");

				function showAlert(status, message){
					$j("##cloudsearch-update-results").append("<div class='alert alert-"+status+"'><button class='close' data-dismiss='alert' type='button'>×</button>"+message+"</div>");
				}
				function showHTML(html){
					tbody.html(html);
				}

				ajaxAction(this.href, '', showAlert, showHTML);
			});

			function regularProcessingCheck() {
				var checkProcessing = setInterval(function() {
					$j.getJSON("#application.fapi.fixURL(addValues='processingupdate=1')#", function(data) {
						var processing = false;

						for (var i=0; i<data.length; i++) {
							if (data[i].domain !== undefined) {
								var n = data[i].processing ? "Yes" : "No";

								if ($j("##domain-info-" + data[i].domain + " .processing").html() === n && n === "No") {
									// do nothing
								}
								else if ($j("##domain-info-" + data[i].domain + " .processing").html() === n) {
									$j("##domain-info-" + data[i].domain + " .processing").addClass("updated");
								}
								else if (data[i].processing) {
									$j("##domain-info-" + data[i].domain + " .processing").addClass("updated-yes").html(n);
								}
								else  {
									$j("##domain-info-" + data[i].domain + " .processing").addClass("updated-no").html(n);
								}

								processing = processing || data[i].processing;
							}
							if (data[i].field !== undefined) {
								if ($j("##field-info-" + data[i].field + " .state").html() === data[i].state && data[i].state === "Active") {
									// do nothing
								}
								else if ($j("##field-info-" + data[i].field + " .state").html() === data[i].state) {
									$j("##field-info-" + data[i].field + " .state").addClass("updated");
								}
								else if (data[i].state === "Processing") {
									$j("##field-info-" + data[i].field + " .state").addClass("updated-no").html(data[i].state);
								}
								else  {
									$j("##field-info-" + data[i].field + " .state").addClass("updated-yes").html(data[i].state);
								}
							}
						}

						if (!processing) {
							clearInterval(checkProcessing);
						}

						setTimeout(function() {
							$j(".updated, .updated-yes, .updated-no").removeClass("updated updated-no updated-yes");
						}, 1000);
					});
				}, 5000);
			}

			<cfif listFind(valueList(qDomains.processing), "true")>
				regularProcessingCheck();
			</cfif>
		</script>
	</cfoutput>
</cfif>

<cfsetting enablecfoutputonly="false">