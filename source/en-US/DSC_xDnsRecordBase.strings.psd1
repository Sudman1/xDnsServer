<#
    .SYNOPSIS
        The localized resource strings in English (en-US) for the
        resource DSC_xDnsRecordBase.
#>

<#
    Exemple of StringData for Class based resource
#>
ConvertFrom-StringData @'
    RetrieveItem = Retrieving Item information of '{0}'.
    ItemFound = Item was found, evaluating all properties.
    ItemNotFound = Item was not found.
    CreateItem = Creating Item '{0}'.
    EvaluateProperties = Evaluating properties of item '{0}'.
    SettingProperties = Setting properties to correct values of item '{0}'.
    RemoveItem = Removing item '{0}'.
    ItemFoundShouldBeNot = Item {0} was found, but should be absent.
    DontBePropertyMandatory = Item should be {0} for PropertyMandatory property, but he is {1}.
    DontBePropertyBoolReadWrite = Item should be {0} for PropertyBoolReadWrite attribute, but he is {1}.
'@

