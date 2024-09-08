Import-Module $PSScriptRoot/../ConvertToTemplate.ps1 -Force

Describe "Sanitize-FileName" {
    It "Removes invalid characters from file name" {
        $result = Sanitize-FileName -fileName "Test:File*Name?.txt"
        $result | Should -Be "Test_File_Name_.txt"
    }

    It "Truncates file name to specified max length" {
        $longFileName = "a" * 250
        $result = Sanitize-FileName -fileName $longFileName -maxLength 100
        $result.Length | Should -Be 100
    }

    It "Handles empty input" {
        $result = Sanitize-FileName -fileName ""
        $result | Should -Be ""
    }
}