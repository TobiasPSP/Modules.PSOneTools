function Get-PsOneFileHash
{
    <#
        .SYNOPSIS
        Calculates a unique hash value for file content and strings, and is capable of calculating partial hashes to speed up calculation for large content

        .DESCRIPTION
        Calculates a cryptographic hash for file content and strings to identify identical content. 
        This can take a long time for large files since the entire file content needs to be read.
        In most cases, duplicate files can safely be identified by looking at only part of their content.
        By using parameters -StartPosition and -Length, you can define the partial content that should be used for hash calculation.
        Any file or string exceeding the size specified in -Length plus -StartPosition will be using a partial hash
        unless -Force is specified. This speeds up hash calculation tremendously, especially across the network.
        It is recommended that partial hashes are verified by calculating a full hash once it matters.
        So if indeed two large files share the same hash, you should use -Force to calculate their hash again.
        Even though you need to calculate the hash twice, calculating a partial hash is very fast and makes sure
        you calculate the expensive full hash only for files that have potential duplicates.

        .EXAMPLE
        Get-PsOneFileHash -String "Hello World!" -Algorithm MD5
        Calculates the hash for a string using the MD5 algorithm

        .EXAMPLE
        Get-PSOneFileHash -Path "$home\Documents\largefile.mp4" -StartPosition 1000 -Length 1MB -Algorithm SHA1
        Calculates the hash for the file content. If the file is larger than 1MB+1000, a partial hash is calculated,
        starting at byte position 1000, and using 1MB of data

        .EXAMPLE
        Get-ChildItem -Path $home -Recurse -File -ErrorAction SilentlyContinue | 
            Get-PsOnePartialFileHash -StartPosition 1KB -Length 1MB -BufferSize 1MB -AlgorithmName SHA1 |
            Group-Object -Property Hash, Length | 
            Where-Object Count -gt 1 |
            ForEach-Object {
                $_.Group | Select-Object -Property Length, Hash, Path
            } |
            Out-GridView -Title 'Potential Duplicate Files'
        Takes all files from the user profile and calculates a hash for each. Large files use a partial hash.
        Results are grouped by hash and length. Any group with more than one member contains potential
        duplicates. These are shown in a gridview.

        .LINK
        https://powershell.one
    #>


    [CmdletBinding(DefaultParameterSetName='File')]
    param
    (
        [Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName,ParameterSetName='File',Position=0)]
        [string]
        [Alias('FullName')]
        # path to file with hashable content
        $Path,

        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='String',Position=0)]
        [string]
        # path to file with hashable content
        $String,

        [int]
        [ValidateRange(0,1TB)]
        # byte position to start hashing
        $StartPosition = 1000,

        [long]
        [ValidateRange(1KB,1TB)]
        # bytes to hash. Larger length increases accuracy of hash.
        # Smaller length increases hash calculation performance
        $Length = 1MB,

        [int]
        # internal buffer size to read chunks
        # a larger buffer increases raw reading speed but slows down
        # overall performance when too many bytes are read and increases
        # memory pressure
        # Ideally, length should be equally dividable by this
        $BufferSize = 32KB,

        [Security.Cryptography.HashAlgorithmName]
        # hash algorithm to use. The fastest algorithm is SHA1. MD5 is second best
        # in terms of speed. Slower algorithms provide more secure hashes with a 
        # lesser chance of duplicates with different content
        $AlgorithmName = 'SHA1',

        [Switch]
        # overrides partial hashing and always calculates the full hash
        $Force
    )

    begin
    {
        # what's the minimum size required for partial hashing?
        $minDataLength = $BufferSize + $StartPosition

        # provide a read buffer. This buffer reads the file content in chunks and feeds the
        # chunks to the hash algorithm:
        $buffer = [Byte[]]::new($BufferSize)

        # are we hashing a file or a string?
        $isFile = $PSCmdlet.ParameterSetName -eq 'File'
    }

    
    process
    {
        # prepare the return object:
        $result = [PSCustomObject]@{
            Path = $Path
            Length = 0
            Algorithm = $AlgorithmName
            Hash = ''
            IsPartialHash = $false
            StartPosition = $StartPosition
            HashedContentSize = $Length
        }
        if ($isFile)
        {
            try
            {
                # check whether the file size is greater than the limit we set:
                $file = [IO.FileInfo]$Path
                $result.Length = $file.Length

                # test whether partial hashes should be used:
                $result.IsPartialHash = ($result.Length -gt $minDataLength) -and (-not $Force.IsPresent)
            }
            catch
            {
                throw "Unable to access $Path"
            }
        }
        else
        {
            $result.Length = $String.Length
            $result.IsPartialHash = ($result.Length -gt $minDataLength) -and (-not $Force.IsPresent)
        }
        # initialize the hash algorithm to use
        # I decided to initialize the hash engine for every file to avoid collisions
        # when using transform blocks. I am not sure whether this is really necessary,
        # or whether initializing the hash engine in the begin() block is safe.
        try
        {
            $algorithmName = [Security.Cryptography.HashAlgorithmName]::SHA1
            $algorithm = [Security.Cryptography.HashAlgorithm]::Create($algorithmName)
        }
        catch
        {
            throw "Unable to initialize algorithm $AlgorithmName"
        }
        try
        {
            if ($isFile)
            {
                # read the file, and make sure the file isn't changed while we read it:
                $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)

                # is the file larger than the threshold so that a partial hash
                # should be calculated?
                if ($result.IsPartialHash)
                {
                    # keep a counter of the bytes that were read for this file:
                    $bytesToRead = $Length

                    # move to the requested start position inside the file content:
                    $stream.Position = $StartPosition

                    # read the file content in chunks until the requested data is fed into the
                    # hash algorithm
                    while($bytesToRead -gt 0)
                    {
                        # either read the full chunk size, or whatever is left to read the desired
                        # total length:
                        $bytesRead = $stream.Read($buffer, 0, [Math]::Min($bytesToRead, $bufferSize))

                        # we should ALWAYS read at least one byte:
                        if ($bytesRead -gt 0)
                        {
                            # subtract the bytes read from the total number of bytes to read
                            # in order to calculate how many bytes need to be read in the next
                            # iteration of this loop:
                            $bytesToRead -= $bytesRead

                            # if there won't be any more bytes to read, this is the last chunk of data,
                            # so we can finalize hash generation:
                            if ($bytesToRead -eq 0)
                            {
                                $null = $algorithm.TransformFinalBlock($buffer, 0, $bytesRead)
                            }
                            # else, if there are more bytes to follow, simply add them to the hash
                            # algorithm:
                            else
                            {
                                $null = $algorithm.TransformBlock($buffer, 0, $bytesRead, $buffer, 0)
                            }
                        }
                        else
                        {
                            throw 'This should never occur: no bytes read.'
                        }
                    }
                }
                else
                {
                    # either the file was smaller than the buffer size, or -Force was used:
                    # the entire file hash is calculated:
                    $null = $algorithm.ComputeHash($stream)
                }
            }
            else
            {
                if ($result.IsPartialHash)
                {
                    $bytes = [Text.Encoding]::UTF8.GetBytes($String.SubString($StartPosition, $Length))
                }
                else
                {
                    $bytes = [Text.Encoding]::UTF8.GetBytes($String)
                }

                $null = $algorithm.ComputeHash($bytes)
            }

            # the calculated hash is stored in the prepared return object:
            $result.Hash = [BitConverter]::ToString($algorithm.Hash).Replace('-','')

            if (!$result.IsPartialHash)
            {
                $result.StartPosition = 0
                $result.HashedContentSize = $result.Length
            }
        }
        catch
        {
            throw "Unable to calculate partial hash: $_"
        }
        finally
        {
            if ($PSCmdlet.ParameterSetName -eq 'File')
            {
                # free stream
                $stream.Close()
                $stream.Dispose()
            }

            # free algorithm and its resources:
            $algorithm.Clear()
            $algorithm.Dispose()
        }
    
        # return result for the file
        return $result
    }
}
return
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

$stopwatch.Reset()
$stopwatch.Start()
$data = Get-ChildItem -Path $env:USERPROFILE\Downloads -File |
Get-PsOnePartialFileHash -StartPosition 1KB -Length 1MB -BufferSize 1MB -AlgorithmName SHA1 
$stopwatch.Stop()

$result = $data | Group-Object -Property Hash, Length | Where-Object Count -gt 1
$duplicates = $result.Count 
$result | ForEach-Object {
    $_.Group | Select-Object -Property Length, Hash, Path
} |
Out-GridView -Title 'Partial Hash'

$seconds = $stopwatch.ElapsedMilliseconds/1000
'partial hashing took {0:n1} secs. Identified duplicates: {1}' -f $seconds, $duplicates
return
$stopwatch.Reset()
$stopwatch.Start()
$data = Get-ChildItem -Path $env:USERPROFILE\Downloads -File |
Get-PsOnePartialFileHash -Force -AlgorithmName SHA1 
$stopwatch.Stop()

$result = $data | Group-Object -Property Hash, Length | Where-Object Count -gt 1
$duplicates = $result.Count 
$result | ForEach-Object {
    $_.Group | Select-Object -Property Length, Hash, Path
} |
Out-GridView -Title 'Full Hash'

$seconds = $stopwatch.ElapsedMilliseconds/1000
'full hashing took {0:n1} secs. Identified duplicates: {1}' -f $seconds, $duplicates

