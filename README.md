# Perl2Python

A tool to attempt conversion of Perl scripts to Python 2.7. Forever a work in progress

### Use:

Run the script on the commandline. Argument 1 needs to be the file to translate (multiple files will be ignored).

Output will be written to stdout; I'd advise piping it to a file with "./perl2python input.pl > output.py"

If a line is unable to be translated, it will be output as a comment. You'll need to check this manually, as no warnings will be thrown and this can cause serious breakage.
