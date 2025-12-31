import os

x = input("Enter day number: ")

os.mkdir(f"Days/Day{x}")
for file in os.listdir("Days/tpl"):
    with open(f"Days/tpl/{file}") as src:
        with open(f"Days/Day{x}/{file.replace("DayXX", f"Day{x}")}", 'w+') as dest:
            for line in src.readlines():
                dest.write(line.replace("ayXX", f"ay{x}"))

