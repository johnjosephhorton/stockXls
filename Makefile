volume.pdf: eda.R
	Rscript eda.R 

stockX.pdf: stockX.tex volume.pdf
	pdflatex stockX.tex
