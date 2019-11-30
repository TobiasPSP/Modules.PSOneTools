

function Group-ObjectFast
{
    [CmdletBinding(DefaultParameterSetName='Analysis')]
    param
    (
        [Parameter(Mandatory)]
        [string[]]
        $Property,

        [Parameter(ParameterSetName='Analysis')]
        [Switch]
        $NoElement,

        [Parameter(ParameterSetName='Separation')]
        [Switch]
        $AsHashtable,

        [Parameter(ParameterSetName='Separation')]
        [Switch]
        $AsString,

        [Parameter(Mandatory, ValueFromPipeline)]
        [object]
        $InputObject
    )

    begin
    {
        # create an empty hashtable
        $hashtable = @{}
    }


    process
    {
        # calculate the unique key based on the properties
        # submitted by the user
        if ($AsString -or $PSCmdlet.ParameterSetName -eq 'Analysis')
        {
            $key = $(foreach($_ in $Property) { $InputObject.$_ }) -join ','
        }
        else
        {
            $key = foreach($_ in $Property) { $InputObject.$_ }
        } 
        
        # check to see if the key is present already
        if ($hashtable.ContainsKey($key) -eq $false)
        {
            # add an empty array list 
            $hashtable[$key] = [Collections.Arraylist]@()
        }

        # add element to appropriate array list:
        $null = $hashtable[$key].Add($InputObject)
    }

    end
    {
        if ($AsHashtable)
        {
            return $hashtable
        }
        elseif ($NoElement)
        {
            foreach($_ in $hashtable.Keys)
            {
                [PSCustomObject]@{
                    Count = $hashtable[$_].Count
                    Name = $key
                }
            }
        }
        else
        {
            foreach($_ in $hashtable.Keys)
            {
                [PSCustomObject]@{
                    Count = $hashtable[$_].Count
                    Name = $key
                    Group = $hashtable[$_]
                }
            }
        }
    }

}