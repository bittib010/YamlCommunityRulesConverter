# Main Template starts here:
@"
resource symbolicname 'Microsoft.OperationalInsights/workspaces/savedSearches@2020-08-01' = {
  // name: '$guid' // TODO
  // parent: $loganalyticsworkspace // TODO
  // etag: 'string'
  properties: {
    category: 'Hunting Queries'
    displayName: '$($row.Name)'
    // functionAlias: 'string'
    // functionParameters: 'string'
    query: '''$($row.Query)'''
    tags: [
      {
        name: 'description'
        value: '$($row.Description)'
      },
                {  
        "name": "tactics",  
        "value": "$($row.Tactics)"  
      },  
      {  
        "name": "relevantTechniques",  
        "value": "$($row.RelevantTechniques)"  
      }  
    ]
    version: 2 // Current version of query language
  }
}
"@



