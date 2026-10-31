# Processing flow

Archyve pulls data from external sources and makes that data available to users in chat.

## Endpoints

Data arrives at Archyve from Endpoints, Archyve's internal representation of an external system. An Endpoint has a URL and credentials. Admins configure Endpoints. Admins would typically be an IT team or a DevOps team.

## Sources

Once Endpoints are defined, Operators choose which data to pull from those external systems using Sources.

A Source selects a subset of the data in an Endpoint. For example, a Source might pull only two specific folders from a Nextcloud server, or a three Books from a Bookstack server. Operators would typically be the people in charge of a certain data set, like HR or Finance, and would control what data about their teams was accessible in chat.

## Collections

Once Sources are defined, Operators create Collections and choose which Sources to include. A Source may feed multiple Collections.

Collections are what Users use in Chats. If data exists in a Collection, and that Collection is accessible to that User, the user can ask questions of Archyve about the data in that Collection, and Archyve's chatbot will draw on that data to answer the User's questions.

## Flow diagram

```mermaid
flowchart
  bookstack(Bookstack)
  nextcloud(Nextcloud)

  subgraph one [Archyve]
    subgraph two [Admin-managed]
        e1(Endpoint)
        e2(Endpoint)
    end

    subgraph three [Operator-managed]
        s1(Source)
        s2(Source)
        s3(Source)

        c1(Collection)
        c2(Collection)
    end

    e1 --> s1
    e2 --> s2
    e2 --> s3

    s1 --> c1
    s2 --> c1
    s3 --> c2
  end

users(((Users)))

bookstack --> e1
nextcloud --> e2

c1 -->|chat| users
c2 -->|chat| users
```

## Permissions

Access controls, including which Operators can control which Collections pull from which Sources, are details in [Access and roles](access.md).
