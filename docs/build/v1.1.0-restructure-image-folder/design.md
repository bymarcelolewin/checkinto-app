# Release Design Document : v1.1.0-restructure-image-folder
Technical implementation and design guide for the upcoming release.

## 1. Features Summary
_Overview of features included in this release._

This release restructures the static image folder architecture to support multi-tenant scaling and introduces terminology migration from "meetup" to "group" for broader customer applicability.

**Key Features:**
- Restructure `/static/images/` to group-based hierarchy: `images/groups/{groupname}/{category}/`
- Migrate existing images from flat structure to new nested structure
- Update codebase references to use new image paths
- Begin terminology transition from "meetup" to "group" in image organization
- Establish foundation for serving multiple group customers beyond just meetup organizers

## 2. Technical Architecture Overview
_High-level technical structure that supports all features in this release._

**Current Structure:**
```
static/images/
├── meetup/
│   └── coding-with-ai-meetup.png
└── presenters/
    └── marcelo-lewin.png
```

**Target Structure:**
```
static/images/
└── groups/
    └── codingwithai/
        ├── group/
        │   └── coding-with-ai-meetup.png
        ├── events/
        │   └── [empty for now]
        └── talent/
            └── marcelo-lewin.png
```

**Architecture Benefits:**
- **Multi-tenant Ready:** Clear separation of assets by group/organization
- **Scalable:** Easy addition of new groups without conflicts
- **Organized:** Logical categorization by asset type (group, events, talent)
- **Future-proof:** Supports expansion beyond meetup organizers

## 3. Implementation Notes
_Shared technical considerations across all features in this release._

**File Migration Strategy:**
- Physical file moves using file system operations
- Update all hardcoded image path references in components
- Maintain consistent naming conventions within each category
- Group name should match subdomain for consistency (codingwithai.checkinto.io → codingwithai)

**Code Update Requirements:**
- Update TypeScript interfaces if they reference image paths
- Modify component imports for image assets
- Update dynamic image path construction logic to use group-based paths
- Ensure image loading components can handle nested paths

**Database + Runtime Path Logic:**
- Database continues to store only filenames (e.g., "coding-with-ai-meetup.png")
- Runtime extracts group from subdomain (codingwithai.chkin.io → "codingwithai")
- Path construction: `/images/groups/{group}/{category}/{filename}`
- Categories: "group" for meetup logos, "talent" for presenter photos, "events" for future use

**Backwards Compatibility:**
- Clean migration without backwards compatibility (acceptable for internal project)
- All references will be updated in single release
- No fallback logic needed since this is pre-production scaling preparation

## 4. Other Technical Considerations
_Any other technical information that might be relevant to building this release._

**Group Name Mapping:**
- Use subdomain as group identifier (codingwithai.checkinto.io → "codingwithai")
- Maintain lowercase, hyphen-separated naming convention
- Consider future database field to store group image path prefix

**File Organization Standards:**
- **group/**: Logo, branding, general organizational images
- **events/**: Event-specific images, flyers, promotional materials
- **talent/**: Speaker/presenter photos, headshots, profile images

**Performance Considerations:**
- No significant performance impact (same number of files, different paths)
- SvelteKit static asset handling remains unchanged
- Build process and deployment not affected

**Future Extensibility:**
- Structure supports adding new asset categories per group
- Easy integration with dynamic group creation
- Foundation for group-specific asset management features

## 5. Open Questions
_Unresolved technical or product questions affecting this release._

1. **Database Integration:** Should we also update database field names from "meetup" to "group" in this release, or handle image restructuring separately?

> No yet.  I'm actually doing some more updates to the DB, so I will do that as part of 1.2.0 version after this one.

2. **Dynamic Path Resolution:** Do we need dynamic image path resolution based on group context, or can we keep static imports for now?

> For now, static imports are fine.

3. **Asset Validation:** Should we implement validation to ensure uploaded images go to correct group folders?

> Well, right now, I don't have an admin interface, so it will be manual.  Update to the DB field and a move to the folder.  All by humans for now.

4. **Migration Strategy:** For future groups, how should we handle automatic folder creation and asset organization?

> That's for later.   Admin interface.  Not now.

5. **Legacy Support:** Any other areas of the codebase that reference the old folder structure that might not be immediately obvious?

> That's for you to find out and tell me.

Additional question for you, AGENT.
**Aliases in package.json** Instead of hardcoding paths, can we add aliases in package.json (e.g. static/images/groups) so we are not hardcoding everything?  Anything else you can think of too that will help with the maintenance of the app later.