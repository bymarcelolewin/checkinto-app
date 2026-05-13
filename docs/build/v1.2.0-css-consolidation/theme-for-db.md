# Database Theme Configuration Guide

## Overview
This document defines the minimal database fields needed to customize the 5 core visual elements of the CheckInto app using the CSS custom properties system.

## Database Schema Recommendation

### Table: `group_themes` or `meetup_themes`
```sql
CREATE TABLE group_themes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES meetups(id),
  
  -- 1. Background of screens (gradient)
  background_start_color TEXT NOT NULL DEFAULT '#20c05b',
  background_end_color TEXT NOT NULL DEFAULT '#16a34a',
  
  -- 2. Text Colors (hierarchy)
  text_primary_color TEXT NOT NULL DEFAULT '#1f2937',
  text_secondary_color TEXT NOT NULL DEFAULT '#374151', 
  text_muted_color TEXT NOT NULL DEFAULT '#6b7280',
  error_text_color TEXT NOT NULL DEFAULT '#fca5a5',
  
  -- 3. Button Colors
  button_background_color TEXT NOT NULL DEFAULT '#e2e2e2',
  button_text_color TEXT NOT NULL DEFAULT '#065f46',
  button_hover_color TEXT NOT NULL DEFAULT '#d6d6d6',
  
  -- 4. Form Background
  form_background_color TEXT NOT NULL DEFAULT '#e2e2e2',
  
  -- 5. Final Screen Detail Information Background  
  info_background_color TEXT NOT NULL DEFAULT '#e2e2e2',
  info_alt_background_color TEXT NOT NULL DEFAULT '#f3f4f6',
  
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## CSS Variable Mapping

### 1. Background of screens
**Database Fields:**
- `background_start_color` → `--color-primary-gradient-start`
- `background_end_color` → `--color-primary-gradient-end`

**Applied to:**
- Welcome screen background
- Check-in form screen background  
- Confirmation screen background

**JavaScript Implementation:**
```javascript
function applyBackgroundTheme(themeData) {
  document.documentElement.style.setProperty(
    '--color-primary-gradient-start', 
    themeData.background_start_color
  );
  document.documentElement.style.setProperty(
    '--color-primary-gradient-end', 
    themeData.background_end_color
  );
}
```

### 2. Text Colors
**Database Fields:**
- `text_primary_color` → `--color-text-primary`
- `text_secondary_color` → `--color-text-secondary`
- `text_muted_color` → `--color-text-muted`
- `error_text_color` → `--color-error-text`

**Applied to:**
- Headers and main text
- Subheadings and labels
- Supporting text and descriptions
- Error messages

**JavaScript Implementation:**
```javascript
function applyTextTheme(themeData) {
  document.documentElement.style.setProperty('--color-text-primary', themeData.text_primary_color);
  document.documentElement.style.setProperty('--color-text-secondary', themeData.text_secondary_color);
  document.documentElement.style.setProperty('--color-text-muted', themeData.text_muted_color);
  document.documentElement.style.setProperty('--color-error-text', themeData.error_text_color);
}
```

### 3. Button Colors
**Database Fields:**
- `button_background_color` → `--color-content-bg` (used for primary buttons)
- `button_text_color` → `--color-button-text`
- `button_hover_color` → `--color-button-hover-bg`

**Applied to:**
- "Check In" button
- "Check In Another Person" button
- Form submit buttons

**JavaScript Implementation:**
```javascript
function applyButtonTheme(themeData) {
  document.documentElement.style.setProperty('--color-content-bg', themeData.button_background_color);
  document.documentElement.style.setProperty('--color-button-text', themeData.button_text_color);
  document.documentElement.style.setProperty('--color-button-hover-bg', themeData.button_hover_color);
}
```

### 4. Form Background
**Database Fields:**
- `form_background_color` → `--color-content-bg`

**Applied to:**
- Check-in form container background
- Input field containers

**Note:** This reuses the same CSS variable as button background for visual consistency.

### 5. Final Screen Detail Information Background
**Database Fields:**
- `info_background_color` → `--color-content-bg`
- `info_alt_background_color` → `--color-bg-alt`

**Applied to:**
- Event information grid background
- Info item icon backgrounds
- Content cards and containers

**JavaScript Implementation:**
```javascript
function applyInfoBackgroundTheme(themeData) {
  document.documentElement.style.setProperty('--color-content-bg', themeData.info_background_color);
  document.documentElement.style.setProperty('--color-bg-alt', themeData.info_alt_background_color);
}
```

## Complete Theme Application Function

```javascript
function applyCustomTheme(themeData) {
  const root = document.documentElement;
  
  // 1. Background of screens
  root.style.setProperty('--color-primary-gradient-start', themeData.background_start_color);
  root.style.setProperty('--color-primary-gradient-end', themeData.background_end_color);
  
  // 2. Text Colors
  root.style.setProperty('--color-text-primary', themeData.text_primary_color);
  root.style.setProperty('--color-text-secondary', themeData.text_secondary_color);
  root.style.setProperty('--color-text-muted', themeData.text_muted_color);
  root.style.setProperty('--color-error-text', themeData.error_text_color);
  
  // 3. Button Colors & 4. Form Background & 5. Info Background
  // Note: These share the same CSS variable for consistency
  root.style.setProperty('--color-content-bg', themeData.button_background_color);
  root.style.setProperty('--color-button-text', themeData.button_text_color);
  root.style.setProperty('--color-button-hover-bg', themeData.button_hover_color);
  root.style.setProperty('--color-bg-alt', themeData.info_alt_background_color);
}
```

## Usage in SvelteKit

### Load theme in +layout.server.ts
```typescript
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ params, locals }) => {
  // Get group theme from database
  const { data: theme } = await locals.supabase
    .from('group_themes')
    .select('*')
    .eq('group_id', params.groupId)
    .single();
    
  return {
    theme
  };
};
```

### Apply theme in +layout.svelte
```svelte
<script>
  import { onMount } from 'svelte';
  
  export let data;
  
  onMount(() => {
    if (data.theme) {
      applyCustomTheme(data.theme);
    }
  });
</script>
```

## Default Values
All database fields should have default values matching the current theme:

| Field | Default Value | CSS Variable |
|-------|---------------|--------------|
| `background_start_color` | `#20c05b` | `--color-primary-gradient-start` |
| `background_end_color` | `#16a34a` | `--color-primary-gradient-end` |
| `text_primary_color` | `#1f2937` | `--color-text-primary` |
| `text_secondary_color` | `#374151` | `--color-text-secondary` |
| `text_muted_color` | `#6b7280` | `--color-text-muted` |
| `error_text_color` | `#fca5a5` | `--color-error-text` |
| `button_background_color` | `#e2e2e2` | `--color-content-bg` |
| `button_text_color` | `#065f46` | `--color-button-text` |
| `button_hover_color` | `#d6d6d6` | `--color-button-hover-bg` |
| `form_background_color` | `#e2e2e2` | `--color-content-bg` |
| `info_background_color` | `#e2e2e2` | `--color-content-bg` |
| `info_alt_background_color` | `#f3f4f6` | `--color-bg-alt` |

## Visual Impact Summary

**With just these 12 database fields, you can customize:**
- ✅ All screen backgrounds (gradient colors)
- ✅ All text hierarchy (headers, body, muted, errors)  
- ✅ All button appearance and interactions
- ✅ Form container styling
- ✅ Information card backgrounds on confirmation screen

**This covers 95% of the visual customization needs** while maintaining the sophisticated shadow system, typography, and specialized themes (winner announcements, error pages) that enhance the user experience.