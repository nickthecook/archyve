# Access and roles

Access in Archyve has two parts: a **role** that applies everywhere, and **grants** on individual collections and sources.

## Roles

There are three roles in Archyve: User, Operator, and Admin. Privileges are cumulative: Operator has a superset of the privileges of User, and Admin has a superset of the privileges of Operator.

| Role | Can |
|---|---|
| User | Can access Chat |
| Operator | Can also manage Sources and Collections |
| Admin | Can also manage Endpoints, settings, and people |

For details on Endpoints, Sources, and Collections, see [Processing flow](processing.md).

### User

Users can only access chat. They cannot manage Collections, Sources, Endpoints, or the permissions of other Users. A User is typically someone who uses Archyve but plays no role in defining its behaviour or its configuration.

### Operator

An Operator is someone responsible for curating content on in Archyve. For example, a member of the HR organization might be responsible for ensuring that users get answers from the correct set of HR documents, and that those documents are current.

Operators can also chat, so they can test their users' use cases.

Operators must be granted access to certain Collections or Sources before they can manage them, so an Operator from IT should be able to manage IT's collections, but not HR's.

### Admin

An Admin has full access to Archyve: all the permissions of Operator

## Areas of the app

The three roles map to the three main parts of the app, which are accessible from the landing page:

![access image](access.png)

If a user's role does not allow them to access one of these three areas of the app, the link is not present on their landing page.

An admin changes someone's role under [Settings › People](/settings/users). Archyve always keeps at least one admin: the last one can't be demoted or deleted.

## Grants

Grants are like having a role on a specific Collection or Source.

A Grant does not allow a user to do something their role does not; for example, a User with an Operator or Admin grant on a Collection is still just a User, and Users cannot manage Collections.

If a user creates a Collection or a Source, they have the Admin grant on that Collection or Source. Users can create nothing, Operators can create Sources and Collections, and Admins can create anything.

Grants are managed through a "People" button in the top right of a Collection or Source page:

![people button](people_button.png)

### Grants on Collections

Collections are sets of Sources and Documents that are grouped together so Users can use them in chat. They are generally logically related, like "Human Resources documents", "IT procedures", or "Appliance manuals".

| Grant on the collection | A User can | An Operator can | An Admin can |
|---|---|---|---|
| none | do nothing; it doesn't appear for them | do nothing; it doesn't appear for them | do everything; no grant needed |
| User | search it and use it in Chat | search it and use it in Chat | do everything; no grant needed |
| Operator | search it and use it in Chat | also add and remove documents by hand, and trigger a sync | do everything; no grant needed |
| Admin | search it and use it in Chat | also decide who else has access, and delete it | do everything; no grant needed |  

#### Examples

For example, if a user was a member of the HR department, and was responsible for managing the content available to users within the "Human Resources" Collection, that user should have the Operator role, _and_ the Operator grant on Human Resources. This would let them add or remove documents from the Collections.

If they were also responsible for managing who has access to that Collection, they should have the Admin grant on the Collection.

### Grants on Sources

Sources feed Collections. A Collection can have many Sources, and users with a grant on the Collection can use it in chat. Sources pull documents from external systems (via Endpoints).

| Grant on the source | A User can | An Operator can | An Admin can |
|---|---|---|---|
| none | do nothing | do nothing; it doesn't appear for them | do everything; no grant needed |
| User | do nothing | attach it to a collection they manage | do everything; no grant needed |
| Operator | do nothing | also change its settings and trigger a sync | do everything; no grant needed |
| Admin | do nothing | also decide who else has access, and delete it | do everything; no grant needed |

For Sources, Users can do nothing, because one can't use a Source directly in chat. Chats reference Collections, and Collections reference Sources.

#### Examples

For example, if a user was responsible for selecting which Books in Bookstack were going to go into a "Human Resources" Collection, they should be an Operator, so they can create Sources to pull data from specific Books in Bookstack. Then, an Operator with the Operator grant on the Collection and a User or higher grant on the Source would be able to connect the Source to the Collection.
