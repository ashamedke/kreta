import os
import shutil

custom_dir = 'assets/models/custom'
models_dir = 'assets/models'

# Delete old massive files
for f in os.listdir(models_dir):
    if f != 'custom' and os.path.isfile(os.path.join(models_dir, f)):
        os.remove(os.path.join(models_dir, f))

# Create simple materials
with open(os.path.join(models_dir, 'white.mtl'), 'w') as f:
    f.write('newmtl white\nKd 0.9 0.9 0.9\nKa 0.9 0.9 0.9\n')

with open(os.path.join(models_dir, 'black.mtl'), 'w') as f:
    f.write('newmtl black\nKd 0.1 0.1 0.1\nKa 0.1 0.1 0.1\n')

with open(os.path.join(models_dir, 'board.mtl'), 'w') as f:
    f.write('newmtl board\nKd 0.4 0.6 0.4\nKa 0.4 0.6 0.4\n')

pieces = ['pawn', 'knight', 'bishop', 'rook', 'queen', 'king']

for p in pieces:
    src = os.path.join(custom_dir, f"{p}.obj")
    if not os.path.exists(src): continue
    
    with open(src, 'r') as f:
        lines = f.readlines()
        
    lines = [l for l in lines if not l.startswith('mtllib') and not l.startswith('usemtl')]
    
    with open(os.path.join(models_dir, f"white_{p}.obj"), 'w') as f:
        f.write('mtllib white.mtl\nusemtl white\n' + "".join(lines))
        
    with open(os.path.join(models_dir, f"black_{p}.obj"), 'w') as f:
        f.write('mtllib black.mtl\nusemtl black\n' + "".join(lines))

board_src = os.path.join(custom_dir, "board.obj")
if os.path.exists(board_src):
    with open(board_src, 'r') as f:
        lines = f.readlines()
    lines = [l for l in lines if not l.startswith('mtllib') and not l.startswith('usemtl')]
    with open(os.path.join(models_dir, "board.obj"), 'w') as f:
        f.write('mtllib board.mtl\nusemtl board\n' + "".join(lines))

print('Done generating lightweight assets.')
