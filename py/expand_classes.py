import re
import sys

def is_size_token(token):
    """Check if token is a size (number, /name, or s/name)"""
    return (token.isdigit() or 
            token.startswith('/') or 
            token.startswith('s/'))

def expand_class_definition(match):
    tokens = match.group(1).strip().split()
    class_name = tokens[0]
    tokens = tokens[1:]  # Remove class name
    
    result = f"class: {class_name}\n"
    
    # Parse field-space (first size token)
    if tokens and is_size_token(tokens[0]):
        result += f"    {tokens[0]} field-space\n"
        tokens = tokens[1:]
    
    i = 0
    while i < len(tokens):
        token = tokens[i]
        
        # Handle derive class (%classname)
        if token.startswith('%'):
            result += f"    {token[1:]} derive\n"
            
        # Handle works-with traits (+"traitname")
        elif token.startswith('"') and token.endswith('"'):
            trait_name = token[1:-1]  # Remove " and "
            result += f"    works-with {trait_name}\n"
            
        # Handle is-a traits (+traitname)
        elif token.startswith('+'):
            result += f"    is-a {token[1:]}\n"
            
        # Handle properties (non-size, non-special tokens)
        elif not is_size_token(token):
            # Check if next token is a size
            if i + 1 < len(tokens) and is_size_token(tokens[i + 1]):
                result += f"    {tokens[i + 1]} nproperty {token}\n"
                i += 1  # Skip the size token
            else:
                result += f"    property {token}\n"
        
        i += 1
    
    result += "class;"
    return result

def convert_file(filename):
    with open(filename, 'r') as f:
        content = f.read()
    
    pattern = r'\bc:\s+([^;]+);'
    converted = re.sub(pattern, expand_class_definition, content)
    
    with open(filename, 'w') as f:
        f.write(converted)

if __name__ == "__main__":
    convert_file(sys.argv[1])