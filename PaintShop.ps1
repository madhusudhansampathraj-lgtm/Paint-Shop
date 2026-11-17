Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:W=1200; $script:H=760; $script:ink=[Drawing.Color]::FromArgb(35,41,54)
$script:brushSize=8; $script:tool='Brush'; $script:drawing=$false; $script:dirty=$false; $script:filePath=''
$script:paper=New-Object Drawing.Bitmap($script:W,$script:H)
$g=[Drawing.Graphics]::FromImage($script:paper);$g.Clear([Drawing.Color]::White);$g.Dispose()
$script:undo=[Collections.Generic.List[Drawing.Bitmap]]::new();$script:redo=[Collections.Generic.List[Drawing.Bitmap]]::new()

function Update-Title {
    $name=if($script:filePath){[IO.Path]::GetFileName($script:filePath)}else{'Untitled'}
    $mark=if($script:dirty){' *'}else{''};$form.Text="Paint Shop  |  $name$mark"
}
function Save-History {
    $script:undo.Add($script:paper.Clone())
    if($script:undo.Count -gt 30){$script:undo[0].Dispose();$script:undo.RemoveAt(0)}
    foreach($b in $script:redo){$b.Dispose()};$script:redo.Clear();$script:dirty=$true
}
function New-Canvas {
    if($script:dirty -and [Windows.Forms.MessageBox]::Show('Discard unsaved changes?','New canvas','YesNo','Question') -ne 'Yes'){return}
    foreach($b in $script:undo){$b.Dispose()};foreach($b in $script:redo){$b.Dispose()};$script:undo.Clear();$script:redo.Clear()
    $g=[Drawing.Graphics]::FromImage($script:paper);$g.Clear([Drawing.Color]::White);$g.Dispose();$script:filePath='';$script:dirty=$false;$canvas.Invalidate();Update-Title
}
function Open-Canvas {
    $d=New-Object Windows.Forms.OpenFileDialog;$d.Filter='Image files|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*.*'
    if($d.ShowDialog() -ne 'OK'){return}
    try{$img=[Drawing.Image]::FromFile($d.FileName);$bmp=New-Object Drawing.Bitmap($img);$img.Dispose();$script:paper.Dispose();$script:paper=$bmp;$script:W=$bmp.Width;$script:H=$bmp.Height;$script:filePath=$d.FileName;$script:dirty=$false;foreach($b in $script:undo){$b.Dispose()};foreach($b in $script:redo){$b.Dispose()};$script:undo.Clear();$script:redo.Clear();$canvas.Size=[Drawing.Size]::new($script:W,$script:H);$canvas.Invalidate();Update-Title}catch{[Windows.Forms.MessageBox]::Show("Could not open image: $($_.Exception.Message)",'Paint Shop','OK','Error')|Out-Null}
}
function Save-Canvas([bool]$saveAs=$false) {
    if($saveAs -or -not $script:filePath){$d=New-Object Windows.Forms.SaveFileDialog;$d.Filter='PNG image|*.png|JPEG image|*.jpg|Bitmap image|*.bmp';$d.FileName='My painting.png';if($script:filePath){$d.FileName=[IO.Path]::GetFileName($script:filePath)};if($d.ShowDialog() -ne 'OK'){return};$script:filePath=$d.FileName}
    try{$ext=[IO.Path]::GetExtension($script:filePath).ToLower();$fmt=if($ext -in '.jpg','.jpeg'){'Jpeg'}elseif($ext -eq '.bmp'){'Bmp'}else{'Png'};$script:paper.Save($script:filePath,[Drawing.Imaging.ImageFormat]::$fmt);$script:dirty=$false;Update-Title}catch{[Windows.Forms.MessageBox]::Show("Could not save image: $($_.Exception.Message)",'Paint Shop','OK','Error')|Out-Null}
}
function Undo-Canvas {if($script:undo.Count){$script:redo.Add($script:paper.Clone());$script:paper.Dispose();$script:paper=$script:undo[$script:undo.Count-1];$script:undo.RemoveAt($script:undo.Count-1);$script:dirty=$true;$canvas.Invalidate();Update-Title}}
function Redo-Canvas {if($script:redo.Count){$script:undo.Add($script:paper.Clone());$script:paper.Dispose();$script:paper=$script:redo[$script:redo.Count-1];$script:redo.RemoveAt($script:redo.Count-1);$script:dirty=$true;$canvas.Invalidate();Update-Title}}
function Resize-Canvas {
    $dlg=New-Object Windows.Forms.Form;$dlg.Text='Canvas size';$dlg.FormBorderStyle='FixedDialog';$dlg.StartPosition='CenterParent';$dlg.ClientSize=[Drawing.Size]::new(300,145);$dlg.MaximizeBox=$false;$dlg.MinimizeBox=$false;$dlg.BackColor=[Drawing.Color]::White
    $wl=New-Object Windows.Forms.Label;$wl.Text='Width';$wl.Location=[Drawing.Point]::new(22,20);$wl.AutoSize=$true;$dlg.Controls.Add($wl)
    $ww=New-Object Windows.Forms.NumericUpDown;$ww.Minimum=100;$ww.Maximum=6000;$ww.Value=$script:W;$ww.Location=[Drawing.Point]::new(22,44);$ww.Width=110;$dlg.Controls.Add($ww)
    $hl=New-Object Windows.Forms.Label;$hl.Text='Height';$hl.Location=[Drawing.Point]::new(160,20);$hl.AutoSize=$true;$dlg.Controls.Add($hl)
    $hh=New-Object Windows.Forms.NumericUpDown;$hh.Minimum=100;$hh.Maximum=6000;$hh.Value=$script:H;$hh.Location=[Drawing.Point]::new(160,44);$hh.Width=110;$dlg.Controls.Add($hh)
    $ok=New-Object Windows.Forms.Button;$ok.Text='Resize';$ok.DialogResult='OK';$ok.Location=[Drawing.Point]::new(160,94);$dlg.Controls.Add($ok);$dlg.AcceptButton=$ok
    if($dlg.ShowDialog($form) -eq 'OK' -and ($ww.Value -ne $script:W -or $hh.Value -ne $script:H)){$next=New-Object Drawing.Bitmap([int]$ww.Value,[int]$hh.Value);$gg=[Drawing.Graphics]::FromImage($next);$gg.Clear([Drawing.Color]::White);$gg.DrawImage($script:paper,0,0);$gg.Dispose();Save-History;$script:paper.Dispose();$script:paper=$next;$script:W=[int]$ww.Value;$script:H=[int]$hh.Value;$canvas.Size=[Drawing.Size]::new($script:W,$script:H);$canvas.Invalidate();Update-Title};$dlg.Dispose()
}
function Add-ActionButton($parent,[string]$label,[int]$width,[scriptblock]$action) {
    $b=New-Object Windows.Forms.Button;$b.Text=$label;$b.Size=[Drawing.Size]::new($width,36);$b.Margin=[Windows.Forms.Padding]::new(3,2,3,2);$b.FlatStyle='Flat';$b.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(219,224,232);$b.BackColor=[Drawing.Color]::White;$b.ForeColor=[Drawing.Color]::FromArgb(44,53,68);$b.Font=[Drawing.Font]::new('Segoe UI',9);$b.Cursor='Hand';$b.Add_Click($action);$parent.Controls.Add($b);return $b
}

$form=New-Object Windows.Forms.Form;$form.Text='Paint Shop  |  Untitled';$form.Size=[Drawing.Size]::new(1320,900);$form.MinimumSize=[Drawing.Size]::new(900,650);$form.StartPosition='CenterScreen';$form.BackColor=[Drawing.Color]::FromArgb(244,246,250);$form.Font=[Drawing.Font]::new('Segoe UI',9);$form.KeyPreview=$true
$menu=New-Object Windows.Forms.MenuStrip;$menu.Dock='Top';$menu.BackColor=[Drawing.Color]::White;$menu.ForeColor=[Drawing.Color]::FromArgb(42,50,64);$menu.RenderMode='System';$form.Controls.Add($menu)
$fileMenu=New-Object Windows.Forms.ToolStripMenuItem('File');$editMenu=New-Object Windows.Forms.ToolStripMenuItem('Edit');$viewMenu=New-Object Windows.Forms.ToolStripMenuItem('View');$helpMenu=New-Object Windows.Forms.ToolStripMenuItem('Help');[void]$menu.Items.AddRange(@($fileMenu,$editMenu,$viewMenu,$helpMenu))
$newItem=New-Object Windows.Forms.ToolStripMenuItem('New canvas');$newItem.ShortcutKeys=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::N
$openItem=New-Object Windows.Forms.ToolStripMenuItem('Open image...');$openItem.ShortcutKeys=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::O
$saveItem=New-Object Windows.Forms.ToolStripMenuItem('Save');$saveItem.ShortcutKeys=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::S
$saveAsItem=New-Object Windows.Forms.ToolStripMenuItem('Save as...');$exitItem=New-Object Windows.Forms.ToolStripMenuItem('Exit')
[void]$fileMenu.DropDownItems.AddRange(@($newItem,$openItem,$saveItem,$saveAsItem,(New-Object Windows.Forms.ToolStripSeparator),$exitItem))
$undoItem=New-Object Windows.Forms.ToolStripMenuItem('Undo');$undoItem.ShortcutKeys=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Z
$redoItem=New-Object Windows.Forms.ToolStripMenuItem('Redo');$redoItem.ShortcutKeys=[Windows.Forms.Keys]::Control -bor [Windows.Forms.Keys]::Y;$clearItem=New-Object Windows.Forms.ToolStripMenuItem('Clear canvas')
[void]$editMenu.DropDownItems.AddRange(@($undoItem,$redoItem,(New-Object Windows.Forms.ToolStripSeparator),$clearItem))
$resizeItem=New-Object Windows.Forms.ToolStripMenuItem('Canvas size...');$viewMenu.DropDownItems.Add($resizeItem)|Out-Null
$aboutItem=New-Object Windows.Forms.ToolStripMenuItem('About Paint Shop');$helpMenu.DropDownItems.Add($aboutItem)|Out-Null
$newItem.Add_Click({New-Canvas});$openItem.Add_Click({Open-Canvas});$saveItem.Add_Click({Save-Canvas});$saveAsItem.Add_Click({Save-Canvas $true});$exitItem.Add_Click({$form.Close()});$undoItem.Add_Click({Undo-Canvas});$redoItem.Add_Click({Redo-Canvas});$clearItem.Add_Click({if([Windows.Forms.MessageBox]::Show('Clear the whole canvas?','Clear canvas','YesNo','Question') -eq 'Yes'){Save-History;$g=[Drawing.Graphics]::FromImage($script:paper);$g.Clear([Drawing.Color]::White);$g.Dispose();$canvas.Invalidate()}});$resizeItem.Add_Click({Resize-Canvas});$aboutItem.Add_Click({[Windows.Forms.MessageBox]::Show("Paint Shop`nA simple desktop painting app.`n`nBrush, eraser, line, color palette, undo/redo, and image files.",'About Paint Shop','OK','Information')|Out-Null})

$toolbar=New-Object Windows.Forms.Panel;$toolbar.Dock='Top';$toolbar.Height=92;$toolbar.BackColor=[Drawing.Color]::FromArgb(250,251,253);$form.Controls.Add($toolbar)
$actions=New-Object Windows.Forms.FlowLayoutPanel;$actions.Location=[Drawing.Point]::new(15,15);$actions.Size=[Drawing.Size]::new(345,42);$actions.WrapContents=$false;$actions.BackColor=[Drawing.Color]::Transparent;$toolbar.Controls.Add($actions)
$newButton=Add-ActionButton $actions 'New' 60 {New-Canvas};$openButton=Add-ActionButton $actions 'Open' 64 {Open-Canvas};$saveButton=Add-ActionButton $actions 'Save' 64 {Save-Canvas};$undoButton=Add-ActionButton $actions 'Undo' 64 {Undo-Canvas};$redoButton=Add-ActionButton $actions 'Redo' 64 {Redo-Canvas}
$separator=New-Object Windows.Forms.Label;$separator.BorderStyle='Fixed3D';$separator.Location=[Drawing.Point]::new(375,14);$separator.Size=[Drawing.Size]::new(2,64);$toolbar.Controls.Add($separator)
$toolLabel=New-Object Windows.Forms.Label;$toolLabel.Text='TOOL';$toolLabel.ForeColor=[Drawing.Color]::FromArgb(112,122,139);$toolLabel.Location=[Drawing.Point]::new(395,12);$toolLabel.AutoSize=$true;$toolLabel.Font=[Drawing.Font]::new('Segoe UI',8,[Drawing.FontStyle]::Bold);$toolbar.Controls.Add($toolLabel)
$toolBox=New-Object Windows.Forms.ComboBox;$toolBox.DropDownStyle='DropDownList';[void]$toolBox.Items.AddRange(@('Brush','Eraser','Line'));$toolBox.SelectedIndex=0;$toolBox.Location=[Drawing.Point]::new(395,36);$toolBox.Width=105;$toolbar.Controls.Add($toolBox);$toolBox.Add_SelectedIndexChanged({$script:tool=$toolBox.SelectedItem})
$sizeLabel=New-Object Windows.Forms.Label;$sizeLabel.Text='BRUSH SIZE';$sizeLabel.ForeColor=[Drawing.Color]::FromArgb(112,122,139);$sizeLabel.Location=[Drawing.Point]::new(520,12);$sizeLabel.AutoSize=$true;$sizeLabel.Font=[Drawing.Font]::new('Segoe UI',8,[Drawing.FontStyle]::Bold);$toolbar.Controls.Add($sizeLabel)
$sizeBox=New-Object Windows.Forms.NumericUpDown;$sizeBox.Minimum=1;$sizeBox.Maximum=80;$sizeBox.Value=8;$sizeBox.Location=[Drawing.Point]::new(520,36);$sizeBox.Width=64;$toolbar.Controls.Add($sizeBox);$sizeBox.Add_ValueChanged({$script:brushSize=[int]$sizeBox.Value})
$colorLabel=New-Object Windows.Forms.Label;$colorLabel.Text='COLOR';$colorLabel.ForeColor=[Drawing.Color]::FromArgb(112,122,139);$colorLabel.Location=[Drawing.Point]::new(610,12);$colorLabel.AutoSize=$true;$colorLabel.Font=[Drawing.Font]::new('Segoe UI',8,[Drawing.FontStyle]::Bold);$toolbar.Controls.Add($colorLabel)
$colors=@('#232936','#FFFFFF','#E5484D','#F76B15','#F5A623','#F2C94C','#46A758','#12A594','#0091FF','#3E63DD','#8E4EC6','#D6409F','#7D8796','#66594C')
for($i=0;$i -lt $colors.Count;$i++){$sw=New-Object Windows.Forms.Button;$sw.Size=[Drawing.Size]::new(25,25);$sw.Location=[Drawing.Point]::new((610+$i*30),36);$sw.BackColor=[Drawing.ColorTranslator]::FromHtml($colors[$i]);$sw.FlatStyle='Flat';$sw.FlatAppearance.BorderColor=[Drawing.Color]::FromArgb(205,211,221);$sw.Tag=$colors[$i];$sw.Add_Click({$script:ink=[Drawing.ColorTranslator]::FromHtml($this.Tag)});$toolbar.Controls.Add($sw)}
$custom=Add-ActionButton $toolbar 'Custom color...' 105 { $d=New-Object Windows.Forms.ColorDialog;$d.Color=$script:ink;if($d.ShowDialog() -eq 'OK'){$script:ink=$d.Color} };$custom.Location=[Drawing.Point]::new(610,65);$custom.Size=[Drawing.Size]::new(105,24)

$canvasHost=New-Object Windows.Forms.Panel;$canvasHost.Dock='Fill';$canvasHost.AutoScroll=$true;$canvasHost.BackColor=[Drawing.Color]::FromArgb(229,233,240);$form.Controls.Add($canvasHost);$canvasHost.BringToFront();$toolbar.BringToFront();$menu.BringToFront()
$canvas=New-Object Windows.Forms.Panel;$canvas.Size=[Drawing.Size]::new($script:W,$script:H);$canvas.BackColor=[Drawing.Color]::White;$canvas.BorderStyle='FixedSingle';$canvas.Location=[Drawing.Point]::new(28,28);$canvasHost.Controls.Add($canvas)
$status=New-Object Windows.Forms.StatusStrip;$status.BackColor=[Drawing.Color]::White;$status.SizingGrip=$false;$statusLabel=New-Object Windows.Forms.ToolStripStatusLabel('1200 Ã— 760 px');[void]$status.Items.Add($statusLabel);$hint=New-Object Windows.Forms.ToolStripStatusLabel('Ctrl+O Open   â€¢   Ctrl+S Save   â€¢   Ctrl+Z Undo');$hint.Spring=$true;$hint.TextAlign='MiddleRight';[void]$status.Items.Add($hint);$form.Controls.Add($status);$status.BringToFront()
$canvas.Add_Paint({$e=$args[1];$e.Graphics.InterpolationMode='HighQualityBicubic';$e.Graphics.DrawImage($script:paper,0,0,$script:W,$script:H)})
$canvas.Add_MouseDown({if($args[1].Button -eq 'Left'){Save-History;$script:drawing=$true;$script:lastPoint=$args[1].Location;if($script:tool -ne 'Line'){$g=[Drawing.Graphics]::FromImage($script:paper);$c=if($script:tool -eq 'Eraser'){[Drawing.Color]::White}else{$script:ink};$br=New-Object Drawing.SolidBrush($c);$d=$script:brushSize;$g.FillEllipse($br,$script:lastPoint.X-$d/2,$script:lastPoint.Y-$d/2,$d,$d);$br.Dispose();$g.Dispose();$canvas.Invalidate()}}})
$canvas.Add_MouseMove({if($script:drawing -and $script:tool -ne 'Line' -and ($args[1].Button -band [Windows.Forms.MouseButtons]::Left)){$g=[Drawing.Graphics]::FromImage($script:paper);$c=if($script:tool -eq 'Eraser'){[Drawing.Color]::White}else{$script:ink};$pen=New-Object Drawing.Pen($c,$script:brushSize);$pen.StartCap='Round';$pen.EndCap='Round';$g.DrawLine($pen,$script:lastPoint,$args[1].Location);$pen.Dispose();$g.Dispose();$script:lastPoint=$args[1].Location;$canvas.Invalidate()}})
$canvas.Add_MouseUp({if($script:drawing -and $script:tool -eq 'Line' -and $args[1].Button -eq 'Left'){$g=[Drawing.Graphics]::FromImage($script:paper);$pen=New-Object Drawing.Pen($script:ink,$script:brushSize);$g.DrawLine($pen,$script:lastPoint,$args[1].Location);$pen.Dispose();$g.Dispose();$canvas.Invalidate()};$script:drawing=$false})
$form.Add_KeyDown({if($_.Control -and $_.KeyCode -eq 'O'){Open-Canvas};if($_.Control -and $_.KeyCode -eq 'S'){Save-Canvas};if($_.Control -and $_.KeyCode -eq 'Z'){Undo-Canvas};if($_.Control -and $_.KeyCode -eq 'Y'){Redo-Canvas}})
$form.Add_FormClosing({if($script:dirty -and [Windows.Forms.MessageBox]::Show('Close without saving your changes?','Paint Shop','YesNo','Question') -ne 'Yes'){$_.Cancel=$true}})
$form.Add_FormClosed({foreach($b in $script:undo){$b.Dispose()};foreach($b in $script:redo){$b.Dispose()};$script:paper.Dispose()})
[void]$form.ShowDialog()

