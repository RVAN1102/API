import os

def fix_line_endings(directory):
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith('.sh') or file.endswith('.js') or file.endswith('.py'):
                path = os.path.join(root, file)
                try:
                    with open(path, 'rb') as f:
                        content = f.read()
                    new_content = content.replace(b'\r\n', b'\n')
                    if new_content != content:
                        with open(path, 'wb') as f:
                            f.write(new_content)
                        print(f"Fixed CRLF in {path}")
                except Exception as e:
                    print(f"Error processing {path}: {e}")

fix_line_endings('d:/SUBJECTS/Matmahoc/Project_CK/API')
print("Line endings fixed.")
