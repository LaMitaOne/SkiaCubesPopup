# SkiaCubesPopup
A floating, 3D-cube grid popup menu for Delphi VCL, rendered entirely via Skia4Delphi.     
   
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/LaMitaOne/SkiaCubesPopup)

<img width="532" height="299" alt="Unbenannt" src="https://github.com/user-attachments/assets/936ee5c5-caeb-44ea-8a14-4bd507eab73b" />   
              
Bypasses standard VCL limitations by using the Windows UpdateLayeredWindow API combined with Skia to deliver a smooth, anti-aliased grid menu with true per-pixel alpha transparency and soft drop shadows. No clFuchsia masking, no jagged edges, no flickering. Uses natively passed TAlphaColor for flawless color rendering.    
    
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
   v 0.3:     
   - Ported the CirclePopup WinAPI UpdateLayeredWindow pipeline to Cubes    
   - Using TAlphaColor natively to prevent color type crashes    
   - Added true drop shadows using Skia ImageFilters    
   - Enabled true Anti-Aliasing for smooth rounded cube edges    
   - Using PNG stream for 100% safe VCL Alpha transfer    
     
Sample project and zipped exe included :)     

   
