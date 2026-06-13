# Framework Tailoring for Implementation and Theoretical Research

## Introduction

This document outlines how the proposed project frameworks for the twelve security topics are tailored to support both practical implementation and theoretical research, making them suitable for an undergraduate student in a security program. The goal is to provide a structure that allows students to gain hands-on experience while also engaging in academic inquiry, critical analysis, and conceptual design. The framework emphasizes flexibility in technology choices, encouraging students to explore various tools and platforms relevant to each topic.

Each project topic is designed to have distinct implementation components, where students can build, configure, or test security mechanisms, and theoretical research components, where students can delve into underlying principles, compare approaches, analyze security models, and explore future directions. The synergy between these two aspects is crucial: practical challenges encountered during implementation can spur deeper theoretical investigation, while theoretical understanding can guide more effective and secure implementations.

This dual approach ensures that students not only learn *how* to implement security solutions but also *why* certain approaches are preferred, what their limitations are, and how they fit into the broader landscape of cybersecurity research and practice. The following sections detail this tailoring for each project topic.



## Topic 1: Cryptanalysis on Symmetric Ciphers

**Implementation Focus:**

*   **Cipher Implementation:** Students can implement a simplified version of a known symmetric cipher (e.g., a few rounds of AES, DES, or a toy cipher like S-DES) or a hypothetical one provided in the project description. This involves understanding and coding the key schedule, round functions, S-boxes, and P-boxes.
*   **Attack Implementation:** Implement one or two basic cryptanalytic attacks, such as a brute-force key search (on a reduced keyspace), basic known-plaintext attack if a simple structural weakness is hypothesized, or collecting data for statistical tests (e.g., frequency analysis, avalanche effect calculation).
*   **Tool Usage:** Learn to use programming languages (Python, C++) and libraries (NumPy for statistical analysis, Matplotlib for visualization) for cryptographic operations and data analysis.

**Theoretical Research Focus:**

*   **Cipher Design Principles:** Research and analyze the design principles of modern symmetric ciphers (e.g., confusion, diffusion, SPN/Feistel structures). Compare different design philosophies.
*   **Cryptanalytic Techniques:** Study various cryptanalytic attacks in theory (linear cryptanalysis, differential cryptanalysis, meet-in-the-middle, etc.). Understand their mathematical foundations, data complexity, and success probability.
*   **Security Proofs (Conceptual):** Explore the concept of provable security against certain classes of attacks, even if not deriving full proofs. Understand the assumptions and models used.
*   **Advanced Ciphers:** Research current NIST standards (AES) and ongoing competitions or research in new symmetric cipher designs (e.g., lightweight cryptography).
*   **Report Writing:** Document the implemented cipher, the attacks performed, results, and a thorough theoretical analysis of the cipher's strengths/weaknesses and the cryptanalytic methods studied.

**Relaxing on Technologies/Platforms:** Students can choose Python for rapid prototyping and its rich libraries, or C/C++ for performance-critical aspects or lower-level understanding. The focus is on the cryptographic concepts, not a specific platform.

## Topic 2: Cryptanalysis on RSA-based Algorithms

**Implementation Focus:**

*   **RSA Component Implementation:** Implement core RSA operations (key generation, encryption/decryption, signing/verification) or interface with a library like PyCryptodome. Focus on understanding parameter choices (p, q, e, d).
*   **Attack Implementation (Simplified):**
    *   Attempt to factor small RSA moduli using available tools (e.g., YAFU, or simple trial division for toy examples).
    *   Implement a basic timing attack probe to collect decryption/signing times for different inputs.
    *   Simulate a simple padding oracle attack (e.g., Bleichenbacher's attack on PKCS#1 v1.5 encryption) by crafting inputs and observing mock error messages.
*   **Tool Usage:** Python, PyCryptodome, gmpy2 (for large number arithmetic), potentially shell scripting for factoring tools.

**Theoretical Research Focus:**

*   **Number Theory Foundations:** Study the number theory underlying RSA (primality testing, Euler's totient function, modular exponentiation, integer factorization problem).
*   **RSA Variants and Padding Schemes:** Research different RSA padding schemes (PKCS#1 v1.5, OAEP, PSS) and their security properties. Understand why proper padding is crucial.
*   **Known RSA Attacks:** In-depth study of various attacks: factoring attacks (QS, NFS), small private exponent attacks (Wiener's), common modulus attack, timing attacks, padding oracle attacks, fault attacks.
*   **Key Length and Security Levels:** Analyze the relationship between RSA key length and security strength, and how it compares to symmetric key equivalents.
*   **Report Writing:** Document implemented components, attack simulations, results, and a comprehensive theoretical analysis of RSA security, its vulnerabilities, and best practices for its use.

**Relaxing on Technologies/Platforms:** The core analysis can be done in Python. The choice of specific factoring tools or libraries is flexible. The emphasis is on understanding RSA's mathematical and practical security aspects.




## Topic 3: Cryptanalysis on ECC-based Algorithms

**Implementation Focus:**

*   **ECC Component Implementation:** Implement basic ECC operations (point addition, scalar multiplication) over a small, well-defined curve (e.g., a small prime field curve). Alternatively, use a library like `tinyec` or `fastecdsa` in Python to perform ECDH key exchange or ECDSA signing/verification.
*   **Attack Implementation (Simplified):**
    *   Implement an invalid curve attack: craft a public key on a different curve and send it to an ECDH key exchange function, observing the outcome.
    *   If multiple signatures from the same key can be obtained (even from a mock source), implement the check for ECDSA nonce (k) reuse and attempt private key recovery.
    *   Collect timing data for ECC scalar multiplication with different inputs to look for basic patterns (illustrative of timing side channels).
*   **Tool Usage:** Python, SageMath (for curve parameter analysis and more advanced ECC math), potentially libraries like `tinyec`, `fastecdsa`.

**Theoretical Research Focus:**

*   **Elliptic Curve Mathematics:** Study the theory of elliptic curves over finite fields, the discrete logarithm problem on elliptic curves (ECDLP), and pairing-based cryptography concepts.
*   **ECC Standards and Curves:** Research standard curves (NIST P-curves, Brainpool, Curve25519, secp256k1) and their security properties, including resistance to known attacks.
*   **Known ECC Attacks:** In-depth study of attacks like invalid curve attacks, small subgroup attacks, twist security, side-channel attacks (timing, power analysis like SPA/DPA), fault attacks on ECC, and issues with ECDSA (nonce reuse, malleable signatures if not handled correctly).
*   **Quantum Impact:** Analyze the impact of Shor's algorithm on ECC and the need for post-quantum alternatives.
*   **Report Writing:** Document implemented components, attack simulations, results, and a comprehensive theoretical analysis of ECC security, its vulnerabilities, and best practices for its use, especially in resource-constrained environments like IoT.

**Relaxing on Technologies/Platforms:** Python is suitable for most implementation. SageMath is invaluable for theoretical exploration. The specific ECC library is less critical than understanding the underlying concepts and attack vectors.

## Topic 4: Cryptanalysis on Lattice-based Algorithms

**Implementation Focus:**

*   **Lattice Algorithm Component (Simplified):** Implement a very simplified version of an LWE-based encryption/decryption or key encapsulation mechanism (KEM). Focus on understanding the matrix operations, error addition, and recovery.
*   **Lattice Reduction Experimentation:** Use SageMath or a library like `fplll` (via Python bindings) to apply LLL or BKZ algorithms to small, constructed lattice problem instances (e.g., trying to find a short vector in a basis, or solving a small CVP/SVP instance related to LWE).
*   **Tool Usage:** Python, SageMath (essential for lattice mathematics and reduction algorithms), potentially `fplll`.

**Theoretical Research Focus:**

*   **Lattice Theory Basics:** Study fundamental concepts of lattices, bases, Gram-Schmidt orthogonalization, Minkowski's theorems, and computational lattice problems (SVP, CVP, SIVP, BDD).
*   **Lattice Reduction Algorithms:** Understand the principles behind LLL, BKZ, and other lattice reduction algorithms. Analyze their complexity and approximation factors.
*   **Lattice-based Cryptosystems:** Research major categories of lattice-based cryptography: LWE-based (FrodoKEM, Kyber), NTRU, GGH, and lattice-based signatures (Dilithium, Falcon). Understand their construction and security assumptions.
*   **Attacks on Lattice Crypto:** Study known attacks, including primal attacks, dual attacks, and how lattice reduction is used to break or assess the security of these schemes.
*   **Quantum Resistance:** Deep dive into why lattice problems are believed to be quantum-resistant. Compare with other PQC families.
*   **Report Writing:** Document any implemented components, lattice reduction experiments, results, and a thorough theoretical analysis of lattice cryptography, its security foundations, and its role in post-quantum cryptography.

**Relaxing on Technologies/Platforms:** SageMath is almost indispensable for this topic. Python can be used for scripting and simpler implementations. The focus is heavily on the mathematical and algorithmic aspects of lattices.




## Topic 5: Multimedia Product Service Platform (e.g., Netflix, Spotify)

**Implementation Focus:**

*   **Model Platform Development:** Build a simplified web application (e.g., using Python with Flask/Django) that mimics core multimedia platform features: user registration/login, a catalog of mock multimedia items, and a (very basic) simulated streaming or content access mechanism.
*   **AES Implementation:** Integrate AES encryption (e.g., using the `cryptography` library in Python) to protect sensitive user data stored by the platform (e.g., user profiles, payment information placeholders).
*   **Chaotic Stream Cipher Implementation:** Implement a chosen chaotic map (e.g., Logistic map, Tent map) to generate a keystream. Use this keystream to encrypt/decrypt a small sample of mock multimedia content (e.g., a text file representing a subtitle track, or a small segment of data).
*   **Tool Usage:** Python (Flask/Django for web app), `cryptography` library, `numpy` (for chaotic map math), basic HTML/CSS/JS for frontend.

**Theoretical Research Focus:**

*   **Multimedia Security Challenges:** Research common security threats to multimedia platforms: content piracy, unauthorized access, account sharing, DRM circumvention, stream manipulation.
*   **Digital Rights Management (DRM):** Study various DRM technologies and techniques (e.g., Widevine, FairPlay, PlayReady). Analyze their strengths, weaknesses, and the 

ongoing cat-and-mouse game between DRM providers and crackers.
*   **Stream Ciphers vs. Block Ciphers for Streaming:** Analyze the suitability of stream ciphers (including chaotic ones) versus block ciphers (in appropriate modes like CTR) for real-time multimedia streaming. Consider performance, error propagation, and security.
*   **Chaotic Cryptography:** Research the field of chaos-based cryptography. Critically evaluate its claimed security benefits and known weaknesses/limitations compared to traditional cryptographic primitives. Understand why it's not widely adopted in mainstream security.
*   **Hybrid Cryptographic Systems:** Explore the rationale and design considerations for hybrid cryptographic systems that combine different primitives (e.g., symmetric and asymmetric, or in this case, AES and a chaotic cipher).
*   **Report Writing:** Document the model platform, the AES and chaotic cipher implementations, test results, and a thorough theoretical discussion on multimedia security, DRM, and a critical assessment of the proposed hybrid solution.

**Relaxing on Technologies/Platforms:** The web framework (Flask, Django, or even a simpler setup) is flexible. The core is understanding the application of different crypto types to a multimedia context and critically evaluating novel approaches like chaotic ciphers.

## Topic 6: Online Shopping Service Platform (e.g., Amazon, Shopee)

**Implementation Focus:**

*   **Model E-commerce Platform:** Develop a simplified web application (Python with Flask/Django) simulating an online store: user accounts, product listings, shopping cart, and a mock checkout/payment process.
*   **AES Implementation:** Use AES (e.g., via `cryptography` library) to encrypt sensitive user data stored by the platform (e.g., shipping addresses, partial payment details if stored).
*   **ECDHE Simulation:** Implement or simulate the ECDHE key exchange process between the client (browser) and the server (during the mock payment phase) to derive a shared secret. This shared secret would then be (conceptually) used to encrypt payment details in transit.
*   **FALCON PQC Signature Integration (Conceptual/Library-based):**
    *   If a usable Python library for FALCON is available (e.g., bindings to `liboqs`), integrate it to sign mock transaction summaries on the server-side and verify them on a mock payment processor side.
    *   If not, implement the *workflow* conceptually: describe where signing/verification would occur, what data is signed, and how keys are managed, even if the actual FALCON operations are stubbed out or replaced with a classical signature for demonstration.
*   **Tool Usage:** Python (Flask/Django), `cryptography` library, potentially a PQC library, HTML/CSS/JS.

**Theoretical Research Focus:**

*   **E-commerce Security Threats:** Research common vulnerabilities in online shopping platforms (OWASP Top 10, payment system vulnerabilities, account takeover, data breaches).
*   **Secure Payment Protocols:** Study standards like TLS, and elements of protocols like 3-D Secure. Understand the roles of different parties (shopper, merchant, payment gateway, issuing bank).
*   **Post-Quantum Signatures for Transactions:** Investigate the need for PQC signatures (like FALCON or Dilithium) to ensure long-term integrity and non-repudiation of financial transactions against future quantum threats.
*   **Key Exchange Mechanisms:** Compare ECDHE with other key exchange methods (e.g., RSA-KEM) in terms of security and performance for establishing secure channels.
*   **PCI DSS Compliance:** Research the Payment Card Industry Data Security Standard and discuss how the proposed cryptographic measures (AES for data at rest, secure channel for data in transit, secure transaction records) align with its requirements (at a high level).
*   **Report Writing:** Document the model platform, crypto integrations, test results, and a comprehensive theoretical analysis of e-commerce security, the role of PQC, and the effectiveness of the proposed solutions.

**Relaxing on Technologies/Platforms:** The specific web framework is flexible. The PQC signature part can be heavily conceptual if library integration is too complex, focusing on the *why* and *where* rather than a perfect implementation.




## Topic 7: Encryption, Access Control, and Query in Cloud-Native DBMS

**Implementation Focus:**

*   **ABE System Implementation:** Implement a Ciphertext-Policy Attribute-Based Encryption (CP-ABE) scheme using a library like Charm-Crypto in Python. This includes implementing the `Setup`, `KeyGen`, `Encrypt`, and `Decrypt` functions.
*   **Attribute Authority (AA) Simulation:** Develop a simple Python script to simulate an AA that manages a universe of attributes and issues ABE secret keys to users based on their assigned attributes.
*   **DBMS Integration:** Set up a containerized DBMS (e.g., PostgreSQL or MongoDB via Docker). Write Python scripts to:
    *   Encrypt sample data (e.g., mock patient records) using ABE with defined access policies.
    *   Store the ABE-encrypted data into the DBMS.
    *   Simulate user queries that retrieve encrypted data, and then attempt decryption based on the user's ABE key and attributes.
*   **Tool Usage:** Python, Charm-Crypto library, Docker, a chosen DBMS (PostgreSQL/MongoDB).

**Theoretical Research Focus:**

*   **Attribute-Based Encryption Theory:** Study the mathematical foundations of ABE (bilinear pairings, policy representation). Compare different ABE schemes (CP-ABE, KP-ABE) and their properties.
*   **Access Control Models:** Research various access control models (DAC, MAC, RBAC, ABAC) and analyze how ABE implements fine-grained ABAC.
*   **Encrypted Database Querying:** Investigate the challenges of performing queries directly on encrypted data. Research techniques like searchable encryption (symmetric/asymmetric), homomorphic encryption (conceptual overview), and how ABE facilitates a "filter-then-decrypt" approach.
*   **ABE Key Management and Revocation:** This is a critical area. Research different approaches to attribute revocation and user revocation in ABE systems (e.g., proxy re-encryption, attribute group keys, periodic key updates). Analyze their complexities and trade-offs.
*   **Security of Cloud-Native DBMS:** Study security considerations specific to cloud-native databases (e.g., secure configuration, IAM integration, network security, encryption at rest/in transit provided by cloud providers vs. application-level encryption like ABE).
*   **Report Writing:** Document the ABE system implementation, DBMS integration, test results (access control enforcement, basic performance), and a thorough theoretical analysis of ABE, encrypted querying, revocation, and its application in cloud DBMS.

**Relaxing on Technologies/Platforms:** The choice of DBMS is flexible. The core is the ABE implementation (Charm-Crypto is a good choice) and the conceptual integration with a database system.

## Topic 8: Secure Network Protocols in IoT-based Smart Cities

**Implementation Focus:**

*   **IoT System Simulation:** Develop Python scripts to simulate:
    *   Multiple IoT devices generating mock sensor data.
    *   An IoT gateway (optional, depending on architecture) aggregating data.
    *   A backend server (e.g., using Flask) to receive and process data.
*   **Secure Protocol Implementation:** Implement a lightweight secure communication protocol between the simulated devices and the backend. This should include:
    *   Mutual authentication (e.g., using pre-shared keys, or simple certificate-based if ambitious).
    *   A lightweight key agreement mechanism (e.g., a simplified Diffie-Hellman variant, or derivation from a master secret).
    *   Data encryption using the derived session key (e.g., AES in a suitable mode).
*   **Tool Usage:** Python (for simulation and protocol logic), `cryptography` library for AES, potentially `paho-mqtt` if using MQTT as a transport layer for the simulation.

**Theoretical Research Focus:**

*   **IoT Network Protocols:** Study common IoT protocols (MQTT, CoAP, LoRaWAN, Zigbee, Bluetooth LE) and their inherent security features and vulnerabilities.
*   **Lightweight Cryptography:** Research cryptographic primitives and protocols designed for resource-constrained IoT devices (e.g., lightweight block ciphers, specific KEX protocols for IoT).
*   **IoT Security Threats:** Analyze the unique threat landscape for smart city IoT deployments (physical attacks on devices, network attacks, data privacy issues, large-scale botnets).
*   **Device Authentication and Key Management in IoT:** Explore different approaches for authenticating millions of devices and managing their cryptographic keys securely and scalably.
*   **Secure Firmware Updates for IoT:** Research mechanisms for securely updating firmware on IoT devices to patch vulnerabilities.
*   **Privacy in Smart Cities:** Investigate privacy implications of large-scale data collection in smart cities and techniques for privacy preservation (e.g., anonymization, differential privacy at a conceptual level).
*   **Report Writing:** Document the simulated IoT system, the implemented secure protocol, test results (authentication success/failure, secure data transmission), and a comprehensive theoretical analysis of IoT security challenges in smart cities, protocol design choices, and proposed solutions.

**Relaxing on Technologies/Platforms:** The simulation can be entirely in Python. The choice of specific IoT transport protocols (MQTT, CoAP) for the simulation is flexible. The focus is on designing and implementing the security layer on top.



## Topic 9: Secure Commercial Transactions in Online Shopping and Payment

**Implementation Focus:**

*   **IBPK System Simulation:** Implement an Identity-Based Public Key (IBPK) system, specifically a simple Identity-Based Encryption (IBE) scheme like Boneh-Franklin, using a library like Charm-Crypto in Python. This includes:
    *   A Private Key Generator (PKG) simulator to perform `Setup` (generate master secret key MSK and public parameters PK) and `Extract` (generate user private key SK_ID based on their identity ID and MSK).
    *   Functions for IBE `Encrypt` (encrypt a message under a user's ID and PK) and `Decrypt` (decrypt using SK_ID).
*   **CRYSTALS-Dilithium Integration (Conceptual/Library-based):**
    *   If a manageable Python library for CRYSTALS-Dilithium is available (e.g., `pypqcrypto` or bindings), integrate it to generate key pairs, sign mock transaction data, and verify signatures.
    *   If direct library use is too complex, simulate the workflow: clearly define where Dilithium signing by a merchant and verification by a payment processor would occur, what data is signed, and how keys are managed, using a classical signature (e.g., ECDSA) as a stand-in for the actual PQC operation for demonstration purposes, while theoretically focusing on Dilithium.
*   **Transaction Flow Simulation:** Develop Python scripts to simulate a simplified secure transaction flow:
    *   Shopper client provides identity.
    *   Merchant server uses IBPK for authentication (e.g., challenge-response) or to encrypt a session key under the shopper's identity.
    *   Merchant server signs the transaction summary using Dilithium (or its stand-in).
    *   Mock payment processor verifies the Dilithium signature.
*   **Tool Usage:** Python, Charm-Crypto, potentially a PQC library or classical signature library as a stand-in.

**Theoretical Research Focus:**

*   **Identity-Based Cryptography:** Study the principles of IBE and Identity-Based Signatures (IBS). Understand the role of the PKG, the key escrow problem, and compare IBPK with traditional PKI.
*   **Post-Quantum Signatures (CRYSTALS-Dilithium):** Research the CRYSTALS-Dilithium signature scheme, its underlying lattice problems (Module-LWE, Module-SIS), its security levels, and performance characteristics. Compare it with other PQC signature candidates.
*   **Secure Payment Architectures:** Analyze security requirements for online payment systems (authentication, confidentiality, integrity, non-repudiation). Study how different cryptographic primitives contribute to these goals.
*   **Combining IBPK and PQC:** Explore the rationale for using IBPK for identity/authentication aspects and PQC signatures for long-term transaction integrity. Discuss potential benefits and complexities of such hybrid approaches.
*   **Threats to Online Transactions:** Investigate common attacks against e-commerce and payment systems (phishing, man-in-the-middle, replay attacks, fraud).
*   **Report Writing:** Document the IBPK and Dilithium (or stand-in) implementations, the simulated transaction flow, test results, and a comprehensive theoretical analysis of IBPK, Dilithium, their application in secure transactions, and the key escrow implications of IBPK.

**Relaxing on Technologies/Platforms:** The focus is on understanding and simulating the cryptographic mechanisms. The Dilithium part can be more conceptual if a simple library isn't readily available, emphasizing its properties and role rather than a perfect low-level implementation.




## Topic 10: Cloud-Native API-Based Network Application Security for Small Company Services

**Implementation Focus:**

*   **API Application Development (Simulated):** Develop a small set of RESTful APIs using Python (Flask or FastAPI) to simulate a cloud-native application for a small company (e.g., basic inventory management, customer lookup for a KiotViet-like service).
*   **Containerization:** Package the API services into Docker containers and use Docker Compose to define and run the multi-container application locally. This simulates a cloud-native deployment environment.
*   **JWT Authentication/Authorization:** Implement JWT-based authentication for API access. This includes token issuance, validation, and basic role-based authorization (e.g., different permissions for admin vs. regular user tokens).
*   **Secure Database Access:** Ensure the API services connect to a backend database (e.g., containerized PostgreSQL or SQLite) using secure practices (e.g., credentials from environment variables, parameterized queries/ORM to prevent SQL injection).
*   **API Security Testing (Basic):** Use tools like Postman or Insomnia to test API endpoints, including authentication, authorization, and basic input validation. Optionally, run a simple automated scanner like OWASP ZAP against the local deployment.
*   **Tool Usage:** Python (Flask/FastAPI), Docker, Docker Compose, a database (PostgreSQL/SQLite), Postman/Insomnia, OWASP ZAP (optional).

**Theoretical Research Focus:**

*   **Cloud-Native Security Principles:** Study security challenges and best practices specific to cloud-native architectures (microservices, containers, serverless). Understand concepts like DevSecOps in this context.
*   **API Security (OWASP API Top 10):** In-depth research of common API vulnerabilities (e.g., Broken Object Level Authorization, Broken User Authentication, Excessive Data Exposure, Injection). Analyze how these apply to the implemented system.
*   **JWT Security:** Investigate JWT standards, common vulnerabilities (e.g., `alg:none`, weak signing keys, insecure storage), and best practices for their use (e.g., short-lived access tokens, refresh tokens, revocation strategies).
*   **Microservices Security:** Explore security patterns for microservices, including inter-service authentication/authorization, service mesh security (e.g., Istio - conceptual), and distributed tracing for security monitoring.
*   **Security for Small Companies:** Analyze the specific security challenges faced by small companies with limited resources when adopting cloud-native technologies. Propose cost-effective security measures.
*   **Report Writing:** Document the API application design, containerization setup, JWT implementation, security testing results, and a comprehensive theoretical analysis of cloud-native API security, focusing on practical solutions for small businesses.

**Relaxing on Technologies/Platforms:** The choice of Python framework (Flask/FastAPI) is flexible. The database can be simple. The key is to demonstrate understanding of API security in a containerized environment and the practical application of JWTs.

## Topic 11: Public Administrative Services via Citizen Services Portal

**Implementation Focus:**

*   **Citizen Portal Development (Simulated):** Build a simplified web application (Python with Flask/Django) to simulate a citizen services portal. Features could include mock user registration/login, a list of available public services, and a basic form for one service (e.g., applying for a mock permit).
*   **QR Code Integration:**
    *   Implement QR code generation (e.g., using the `qrcode` library in Python) for specific use cases: e.g., a QR code for a quick link to a service, or a QR code containing a one-time token for a simplified authentication step.
    *   Simulate the processing of a QR code (e.g., a script that takes the QR data as input and performs an action).
*   **FALCON PQC Signature Integration (Conceptual/Library-based):**
    *   If a usable Python library for FALCON is available, integrate it to sign mock official documents (e.g., the generated permit) by the portal and provide a way to verify the signature.
    *   If not, implement the *workflow* conceptually: describe where FALCON signing/verification would occur, what data is signed, and how keys are managed, potentially using a classical signature as a stand-in for demonstration, while the theoretical focus remains on FALCON.
*   **Tool Usage:** Python (Flask/Django), `qrcode` library, potentially a PQC library or classical signature library, HTML/CSS/JS.

**Theoretical Research Focus:**

*   **E-Government Security:** Study security challenges in digital public services, including citizen authentication, data privacy, integrity of official documents, and accessibility.
*   **Post-Quantum Cryptography for Public Sector:** Analyze the importance of PQC (like FALCON) for ensuring the long-term validity and integrity of government-issued documents and citizen data against future quantum threats.
*   **Secure QR Code Usage:** Research vulnerabilities associated with QR codes (phishing, malicious payloads) and best practices for their secure generation, distribution, and processing in sensitive applications like citizen portals.
*   **Secure Key Agreement for Public Services:** While HTTPS/TLS is standard, research if specific key agreement protocols might be beneficial for certain portal interactions, especially those initiated via less secure channels or requiring stronger session binding.
*   **Citizen Data Privacy and Trust:** Investigate data protection regulations (e.g., GDPR) relevant to citizen portals and how cryptographic measures can help build trust and ensure compliance.
*   **Report Writing:** Document the model portal, QR code and FALCON (or stand-in) integrations, test results, and a thorough theoretical analysis of security for citizen services, PQC adoption, secure QR code practices, and privacy considerations.

**Relaxing on Technologies/Platforms:** The web framework is flexible. The FALCON part can be more conceptual if library integration is difficult. The focus is on the secure interaction design using QR codes and the rationale for PQC in this context.

## Topic 12: Attribute-based Encryption for Healthcare Systems

**Implementation Focus:**

*   **ABE System Implementation:** Implement a Ciphertext-Policy Attribute-Based Encryption (CP-ABE) scheme using a library like Charm-Crypto in Python. This involves the core `Setup`, `KeyGen`, `Encrypt`, and `Decrypt` functionalities.
*   **Attribute Authority (AA) Simulation:** Develop a Python script to simulate an AA that defines and manages healthcare-relevant attributes (e.g., `role:doctor`, `specialty:cardiology`, `hospital_department:ER`, `research_project_ID:XYZ`, `patient_consent_group:ABC`) and issues ABE secret keys to simulated users based on these attributes.
*   **Healthcare Data Simulation:** Create mock healthcare data (e.g., snippets of EHRs, research data points, telemedicine summaries) and define ABE access policies for them.
*   **Access Control Demonstration:** Write Python scripts to:
    *   Encrypt the mock healthcare data using ABE with the defined policies.
    *   Simulate different healthcare professionals/researchers (with different attribute sets and ABE keys) attempting to access and decrypt various pieces of data.
    *   Demonstrate successful decryption for authorized users and failure for unauthorized users.
*   **Tool Usage:** Python, Charm-Crypto library.

**Theoretical Research Focus:**

*   **ABE for Healthcare:** In-depth research on the application of ABE for fine-grained access control in healthcare systems. Analyze its benefits (e.g., dynamic policy enforcement, patient-centric control) and challenges.
*   **Healthcare Data Security and Privacy Regulations:** Study regulations like HIPAA (US), GDPR (EU), and others relevant to protecting sensitive health information. Analyze how ABE can help meet these requirements (e.g., minimum necessary access, auditability).
*   **ABE Key Management and Revocation in Healthcare:** This is a critical and complex area. Research and analyze different ABE revocation schemes (user revocation, attribute revocation) and their suitability/scalability for dynamic healthcare environments. Consider proxy re-encryption, attribute group keys, etc.
*   **Emergency Access Mechanisms ("Break-Glass"):** Design and theoretically analyze secure and auditable emergency access protocols that can bypass standard ABE policies in critical situations while minimizing security risks.
*   **Ethical Considerations:** Discuss ethical implications of using ABE in healthcare, such as fairness in attribute assignment, potential for policy misuse, impact on patient trust, and data ownership.
*   **Performance and Scalability of ABE:** Analyze the computational overhead of ABE operations (encryption, decryption, key generation) and discuss scalability challenges for large healthcare systems.
*   **Report Writing:** Document the ABE system implementation, healthcare scenarios, access control test results, and a comprehensive theoretical analysis of ABE in healthcare, including revocation, emergency access, compliance, ethics, and performance.

**Relaxing on Technologies/Platforms:** The core of this project is the ABE implementation using Charm-Crypto and its conceptual application to healthcare scenarios. No complex frontend or database integration is strictly necessary; Python scripts are sufficient for demonstration.


