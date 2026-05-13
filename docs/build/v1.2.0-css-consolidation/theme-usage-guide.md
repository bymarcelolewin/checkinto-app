# CSS Custom Properties Theme Usage Guide

## Overview
This guide documents how to use and extend the CSS custom properties theme system implemented in v1.2.0-css-consolidation.

## Theme Architecture

### Location
All theme variables are defined in `src/app.css` within the `:root` selector, making them globally available throughout the application.

### When to Edit Which Files

#### **Theme/Color Changes → `src/app.css` ONLY** ✅
For any color, shadow, typography, or theme-related changes:
```css
/* Change colors here in app.css */
:root {
  --color-primary-gradient-start: #20c05b; /* Change this value */
  --color-content-bg: #e2e2e2;             /* Or this */
  --shadow-base: rgba(0, 0, 0, 0.1);       /* Or this */
}
```
**Result:** Changes apply instantly across ALL components automatically.

#### **Layout/Structure Changes → Individual Component Files**
For layout, positioning, animations, or new CSS properties:
```svelte
<!-- src/lib/screens/WelcomeScreen.svelte -->
<style>
  .welcome-content {
    /* Add new layout styles here */
    display: grid;
    grid-template-columns: 1fr 1fr;
    /* Add animations, positioning, etc. */
  }
</style>
```

#### Examples:

**✅ Edit `app.css` for:**
- Change brand colors: `--color-primary-gradient-start: #ff6b6b`
- Adjust shadows: `--shadow-base: rgba(0, 0, 0, 0.1)`
- Switch fonts: `--font-family: 'Inter', sans-serif`
- Add new theme colors: `--color-new-feature: #123456`

**✅ Edit component files for:**
- Change layout from flex to grid
- Add new CSS animations
- Modify responsive breakpoints
- Add new CSS classes or components
- Structural changes to existing components

#### The Power of This System:
**Before (bad):** To change the primary green color, you'd need to edit 4+ files  
**Now (good):** Change one line in `app.css` and it updates everywhere instantly

**Database-driven themes (future):** Just inject new values into the CSS custom properties and the entire app changes theme instantly!

### Variable Categories

#### 1. Primary Colors
```css
/* Primary gradient used across all main screens */
--color-primary-gradient-start: #20c05b;
--color-primary-gradient-end: #16a34a;

/* Main content background */
--color-content-bg: #e2e2e2;
```

**Usage Example:**
```css
.welcome-screen {
  background: linear-gradient(135deg, var(--color-primary-gradient-start) 0%, var(--color-primary-gradient-end) 100%);
}

.content-area {
  background: var(--color-content-bg);
}
```

#### 2. Text Color Hierarchy
```css
--color-text-primary: #1f2937;     /* Dark headers, main text */
--color-text-secondary: #374151;   /* Subheadings */
--color-text-muted: #6b7280;       /* Supporting text */
--color-text-label: #374151;       /* Form labels */
--color-error-text: #fca5a5;       /* Error messages */
```

**Usage Example:**
```css
.info-content h4 {
  color: var(--color-text-primary);
}

.info-content p {
  color: var(--color-text-muted);
}
```

#### 3. Button System
```css
--color-button-text: #065f46;
--color-button-hover-bg: #d6d6d6;
--color-button-secondary-text: #e2e2e2;
--color-button-secondary-bg: rgba(226, 226, 226, 0.2);
--color-button-secondary-border: rgba(226, 226, 226, 0.3);
```

**Usage Example:**
```css
.btn-primary {
  background-color: var(--color-content-bg);
  color: var(--color-button-text);
}

.btn-primary:hover {
  background-color: var(--color-button-hover-bg);
}
```

#### 4. Shadow System
```css
--shadow-base: rgba(0, 0, 0, 0.2);      /* Standard shadows */
--shadow-text: rgba(0, 0, 0, 0.3);      /* Text shadows */
--shadow-light: rgba(0, 0, 0, 0.1);     /* Subtle shadows */
--shadow-medium: rgba(0, 0, 0, 0.15);   /* Medium depth */
```

**Usage Example:**
```css
.meetup-logo {
  box-shadow: 0 4px 12px var(--shadow-base);
}

.success-title {
  text-shadow: 0 2px 4px var(--shadow-text);
}
```

#### 5. Form Input Colors
```css
--color-input-border: #d1d5db;
--color-input-focus: #3b82f6;
--color-input-focus-shadow: rgba(59, 130, 246, 0.2);
```

**Usage Example:**
```css
.input-field {
  border: 1px solid var(--color-input-border);
}

.input-field:focus {
  border-color: var(--color-input-focus);
  box-shadow: 0 0 0 2px var(--color-input-focus-shadow);
}
```

#### 6. Specialized Themes

##### Error Page Theme
```css
--color-error-bg-start: #ff6b6b;
--color-error-bg-end: #ee5a6f;
--color-error-page-text: #2d3748;
--color-error-page-text-muted: #4a5568;
--shadow-error-button: rgba(255, 107, 107, 0.3);
```

##### Success/Winner Theme
```css
--color-success-bg-start: #fbbf24;
--color-success-bg-end: #f59e0b;
--color-winner-border: #10b981;
--color-winner-bg-start: rgba(34, 197, 94, 0.9);
--color-winner-bg-end: rgba(22, 163, 74, 0.9);
--shadow-success: rgba(245, 158, 11, 0.3);
--shadow-winner: rgba(34, 197, 94, 0.4);
```

#### 7. Typography
```css
--font-family: 'DM Sans', system-ui, -apple-system, sans-serif;
```

**Usage Example:**
```css
body {
  font-family: var(--font-family);
}
```

## Best Practices

### 1. Always Use Theme Variables
```css
/* ✅ Good - uses theme variable */
.component {
  color: var(--color-text-primary);
}

/* ❌ Bad - hardcoded color */
.component {
  color: #1f2937;
}
```

### 2. Use Semantic Variable Names
Variables are named by purpose, not by color value:
```css
/* ✅ Good - semantic naming */
background: var(--color-content-bg);

/* ❌ Avoid - color-based naming would be confusing */
background: var(--color-light-gray);
```

### 3. Fallback Support
While not required for modern browsers, you can provide fallbacks:
```css
.component {
  background: #e2e2e2; /* fallback */
  background: var(--color-content-bg);
}
```

### 4. Group Related Styles
When using multiple theme variables in one component, group them logically:
```css
.raffle-winner-announcement {
  /* Background theme */
  background: linear-gradient(135deg, var(--color-success-bg-start) 0%, var(--color-success-bg-end) 100%);
  
  /* Shadow theme */
  box-shadow: 0 10px 25px var(--shadow-success);
  
  /* Text theme */
  color: white;
}
```

## Adding New Theme Variables

### 1. Define in app.css
Add new variables to the `:root` selector in `src/app.css`:
```css
:root {
  /* Existing variables... */
  
  /* New variable */
  --color-new-feature: #your-color;
}
```

### 2. Use Semantic Naming
Follow the established prefixes:
- `--color-` for colors
- `--shadow-` for shadows
- `--overlay-` for transparent overlays
- `--font-` for typography

### 3. Document Usage
Add comments explaining the purpose:
```css
/* New feature highlight color */
--color-feature-highlight: #e3f2fd;
```

## Extending for Custom Themes

### Database-Driven Themes (Future)
The current system can be extended to support database-driven themes:

```javascript
// Future implementation example
function applyCustomTheme(themeData) {
  const root = document.documentElement;
  
  root.style.setProperty('--color-primary-gradient-start', themeData.primaryStart);
  root.style.setProperty('--color-primary-gradient-end', themeData.primaryEnd);
  root.style.setProperty('--color-content-bg', themeData.contentBg);
  // ... other theme properties
}
```

### Dark Mode Support (Future)
Dark mode can be implemented by overriding theme variables:
```css
@media (prefers-color-scheme: dark) {
  :root {
    --color-content-bg: #1f2937;
    --color-text-primary: #ffffff;
    --color-text-secondary: #d1d5db;
    /* ... other dark mode overrides */
  }
}
```

## Variable Reference

### Complete List by Category

#### Core Colors (6 variables)
- `--color-primary-gradient-start`
- `--color-primary-gradient-end` 
- `--color-content-bg`
- `--color-error-text`
- `--shadow-base`
- `--shadow-text`

#### Text & Accents (8 variables)
- `--color-text-primary`
- `--color-text-secondary`
- `--color-text-muted`
- `--color-text-label`
- `--color-accent`
- `--color-accent-dark`
- `--color-bg-alt`
- `--color-bg-white`

#### Button System (8 variables)
- `--color-button-text`
- `--color-button-hover-bg`
- `--color-button-secondary-text`
- `--color-button-secondary-bg`
- `--color-button-secondary-border`
- `--color-button-secondary-hover-bg`
- `--color-button-secondary-hover-border`

#### Form Inputs (3 variables)
- `--color-input-border`
- `--color-input-focus`
- `--color-input-focus-shadow`

#### Error Theme (4 variables)
- `--color-error-bg-start`
- `--color-error-bg-end`
- `--color-error-page-text`
- `--color-error-page-text-muted`

#### Success/Winner Theme (5 variables)
- `--color-success-bg-start`
- `--color-success-bg-end`
- `--color-winner-border`
- `--color-winner-bg-start`
- `--color-winner-bg-end`

#### Advanced Shadows (14 variables)
- `--shadow-light`
- `--shadow-medium`
- `--shadow-error-button`
- `--shadow-success`
- `--shadow-winner`
- `--shadow-winner-pulse-start`
- `--shadow-winner-pulse-end`
- `--overlay-white-light`
- `--overlay-white`
- `--overlay-white-border`

#### Typography (1 variable)
- `--font-family`

**Total: 48 CSS custom properties**

## Migration Notes

### From Hardcoded Colors
When migrating existing code:

1. **Identify the color's purpose** (not just its value)
2. **Find the appropriate semantic variable**
3. **Replace the hardcoded value**
4. **Test visual consistency**

### Example Migration
```css
/* Before */
.winner-item.is-you {
  background: linear-gradient(135deg, rgba(34, 197, 94, 0.9) 0%, rgba(22, 163, 74, 0.9) 100%);
  border: 2px solid #10b981;
  box-shadow: 0 4px 20px rgba(34, 197, 94, 0.4);
}

/* After */
.winner-item.is-you {
  background: linear-gradient(135deg, var(--color-winner-bg-start) 0%, var(--color-winner-bg-end) 100%);
  border: 2px solid var(--color-winner-border);
  box-shadow: 0 4px 20px var(--shadow-winner);
}
```

This approach ensures consistency and makes future theme updates much easier.