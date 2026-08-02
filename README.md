# SkiaCubesPopup
A floating, Cube grid popup menu for Delphi VCL, rendered entirely via Skia4Delphi.     
   
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/SkiaCubesPopup)
   
<img width="365" height="235" alt="Unbenannt" src="https://github.com/user-attachments/assets/e343ae60-d778-41ff-a20d-dd8dec324b7b" />
   
Bypasses standard VCL limitations by using the Windows UpdateLayeredWindow API combined with Skia to deliver a smooth, anti-aliased grid menu with true per-pixel alpha transparency and soft drop shadows. No clFuchsia masking, no jagged edges, no flickering.     
    
Features    
    
    True Anti-Aliasing & Alpha: Flawless per-pixel transparency via WS_EX_LAYERED.   
    Soft Drop Shadows: Genuine, soft drop shadows rendered via Skia ImageFilter.    
    Rounded Corners: Cubes are rendered with a subtle 8px corner radius and a 3D inner border stroke.    
    Dynamic Grid: Automatically calculates a 3-column x 2-row grid based on the number of items passed.    
    Zero Flicker: Rendered off-screen and pushed directly to the Windows Compositor.    
   
Requirements   
   
    Delphi (10.3 Rio or newer recommended)   
    Skia4Delphi must be installed.    
      

  Latest Changes   
    
   v 0.4:   
   - Per-Segment color tracking! Each cube fades individually between states.   
   - Smooth Alpha Fade-In and Fade-Out (Show/Close).   
   - Renamed Inner/OuterRadius conceptually to Gap/CubeSize (Interface remains compatible).    
       
   v 0.3:     
   - Ported the CirclePopup WinAPI UpdateLayeredWindow pipeline to Cubes    
   - Using TAlphaColor natively to prevent color type crashes    
   - Added true drop shadows using Skia ImageFilters    
   - Enabled true Anti-Aliasing for smooth rounded cube edges    
   - Using PNG stream for 100% safe VCL Alpha transfer    
     
Sample project and zipped exe included :)     

   
Skia circle popup https://github.com/LaMitaOne/skia-circlepopup
