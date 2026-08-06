$pdf_mode = 5;
$xelatex = 'xelatex %O %S';
# Manche Editor-Rezepte erzwingen "latexmk -pdf". Auch in diesem Fall
# muss wegen fontspec XeLaTeX statt pdfLaTeX ausgeführt werden.
$pdflatex = 'xelatex %O %S';
$bibtex_use = 2;
$clean_ext .= ' run.xml';
