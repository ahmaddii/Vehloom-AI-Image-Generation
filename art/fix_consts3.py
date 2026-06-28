import re

with open('invalid_constants.txt', 'r') as f:
    lines = f.readlines()

file_changes = {}

for line in lines:
    if "Invalid constant value" not in line: continue
    parts = line.split("•")
    if len(parts) >= 3:
        filepath_line = parts[2].strip().split(':')
        if len(filepath_line) >= 2:
            filepath = filepath_line[0]
            lineno = int(filepath_line[1]) - 1
            
            if filepath not in file_changes:
                with open(filepath, 'r') as f2:
                    file_changes[filepath] = f2.readlines()
            
            content = file_changes[filepath]
            
            # search backwards for 'const ' up to 30 lines
            for i in range(lineno, max(-1, lineno - 30), -1):
                if 'const ' in content[i]:
                    content[i] = re.sub(r'\bconst\s+', '', content[i], count=1)
                    break

for filepath, content in file_changes.items():
    with open(filepath, 'w') as f:
        f.writelines(content)
