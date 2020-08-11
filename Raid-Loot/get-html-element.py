from sys import argv
from bs4 import BeautifulSoup

script, first = argv

with open(first) as fp:
    soup = BeautifulSoup(fp, "lxml");

print(soup.find_all("noscript")[1::-1])
