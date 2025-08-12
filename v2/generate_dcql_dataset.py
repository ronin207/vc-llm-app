import json
import random
from typing import List, Dict, Any, Tuple, Optional
import os

# Natural language attribute mappings
NATURAL_LANGUAGE_MAPPINGS = {
    "dateOfBirth": ["birthday", "birth date", "DOB", "date of birth", "when I was born", "my birthday", "born on"],
    "fullName": ["name", "my name", "full name", "complete name", "person's name", "who I am"],
    "nationalId": ["ID number", "my ID", "identification number", "national ID", "ID card number", "citizen ID"],
    "address": ["home address", "where I live", "residence", "living address", "my address", "location"],
    "insuranceNumber": ["insurance ID", "policy number", "insurance number", "my insurance ID", "insurance code"],
    "insuredName": ["policy holder", "insured person", "my name on insurance", "insurance holder name"],
    "licenseNumber": ["license ID", "license no", "my license number", "certification number", "permit number"],
    "testDate": ["when I took the test", "exam date", "test day", "date of examination", "testing date"],
    "employeeName": ["worker name", "staff name", "employee's name", "my name at work", "work name"],
    "employeeId": ["employee number", "staff ID", "worker ID", "my work ID", "employee code"],
    "candidateName": ["test taker", "examinee name", "person who took the test", "my name", "applicant name"],
    "patientName": ["patient", "person's name", "medical record name", "my name", "patient's name"],
    "grade": ["level", "test level", "certification level", "my grade", "which grade", "what level"],
    "department": ["which department", "my department", "work unit", "division", "where I work"],
    "position": ["job title", "my role", "position at work", "what I do", "job position"],
    "bloodType": ["blood group", "my blood type", "blood classification", "what blood type"],
    "vaccinations": ["shots", "immunizations", "vaccines received", "vaccination history", "jabs"],
    "creditScore": ["credit rating", "financial score", "credit points", "credit standing"],
    "gpa": ["grade point average", "academic score", "grades", "academic performance", "GPA"],
    "degreeType": ["degree level", "education level", "what degree", "qualification type"],
    "major": ["field of study", "what I studied", "specialization", "study area", "academic major"],
    "licenseClass": ["license type", "what kind of license", "license category", "permit type"],
    "insuranceType": ["insurance category", "type of insurance", "insurance plan", "coverage type"],
    "score": ["test score", "points", "result", "marks", "test result"],
    "totalScore": ["total points", "overall score", "combined score", "final score"],
    "studentName": ["student", "learner name", "pupil name", "my name as student"],
    "studentId": ["student number", "student code", "learner ID", "academic ID"],
    "passportNumber": ["passport ID", "travel document number", "passport code"],
    "nationality": ["citizenship", "where I'm from", "country of origin", "my nationality"],
    "sex": ["gender", "male/female", "biological sex"],
    "gender": ["sex", "male/female", "gender identity"],
    "joinDate": ["start date", "when I joined", "employment start", "hire date"],
    "employmentType": ["work type", "job type", "full-time/part-time", "employment status"],
    "fiscalYear": ["tax year", "financial year", "year of income"],
    "annualIncome": ["yearly income", "annual salary", "yearly earnings", "annual pay"],
    "certificateNumber": ["certificate ID", "cert number", "certification code", "document number"],
    "issueDate": ["when issued", "date issued", "issuance date", "when it was issued"],
    "checkDate": ["examination date", "when checked", "inspection date"],
    "holderName": ["holder", "owner name", "account holder", "whose name"],
    "accountHolder": ["account owner", "whose account", "bank account name"],
    "licenseHolder": ["license owner", "who has the license", "licensed person"],
    "artistName": ["artist", "tattoo artist name", "artist's name"],
    "sommelierName": ["sommelier", "wine expert name", "certified sommelier"],
    "inspectorName": ["inspector", "inspector's name", "who inspected"],
    "hunterName": ["hunter", "hunting license holder", "licensed hunter"],
    "jewelerName": ["jeweler", "jewelry expert", "certified jeweler"],
    "cosmetologistName": ["beautician", "cosmetologist", "beauty professional"],
    "officerName": ["officer", "police officer name", "officer's name"],
    "teacherName": ["teacher", "educator name", "instructor name"],
    "taxpayerName": ["taxpayer", "tax filer", "person paying tax"],
    "travelerName": ["traveler", "passenger name", "person traveling"],
    "attendeeName": ["attendee", "conference participant", "who attended"],
    "guestName": ["guest", "hotel guest", "visitor name"]
}

# Expiration field variations
EXPIRATION_FIELDS = [
    "expirationDate", "validUntil", "expiredAt", "dateOfExpiry", 
    "validThrough", "expiresOn", "validTo", "endDate", "validity",
    "expiryDate", "validityEnd", "expires"
]

# Natural query templates for Pattern 1
PATTERN1_NATURAL_TEMPLATES = [
    "Show me my {natural_attrs} from the {natural_credential}",
    "I need to see {natural_attrs} in my {natural_credential}",
    "Can you display {natural_attrs} from {natural_credential}",
    "I want to view {natural_attrs} from the {natural_credential}",
    "Please show {natural_attrs} from my {natural_credential}",
    "Get me {natural_attrs} from {natural_credential}",
    "I'd like to see {natural_attrs} in {natural_credential}",
    "Display {natural_attrs} from my {natural_credential}",
    "What's {natural_attrs} in my {natural_credential}",
    "Show {natural_attrs} from the {natural_credential} please"
]

# Natural query templates for Pattern 2
PATTERN2_NATURAL_TEMPLATES = [
    "Show my {natural_credential} but hide {natural_hide_attrs}",
    "I need my {natural_credential} without showing {natural_hide_attrs}",
    "Display {natural_credential} but keep {natural_hide_attrs} private",
    "Can I see {natural_credential} without {natural_hide_attrs}",
    "Show {natural_credential} but don't reveal {natural_hide_attrs}",
    "I want {natural_credential} but hide {natural_hide_attrs}",
    "Get my {natural_credential} excluding {natural_hide_attrs}",
    "Display the {natural_credential} without {natural_hide_attrs}",
    "Show me {natural_credential} but mask {natural_hide_attrs}",
    "I need {natural_credential} keeping {natural_hide_attrs} hidden"
]

# Natural query templates for Pattern 3
PATTERN3_NATURAL_TEMPLATES = [
    "Show only {natural_show_attrs} from my {natural_credential} and hide {natural_hide_attrs}",
    "I need {natural_show_attrs} from {natural_credential} but not {natural_hide_attrs}",
    "Display just {natural_show_attrs} from {natural_credential}, hiding {natural_hide_attrs}",
    "Can I see {natural_show_attrs} in {natural_credential} without {natural_hide_attrs}",
    "Show me {natural_show_attrs} from {natural_credential} but keep {natural_hide_attrs} private",
    "I want only {natural_show_attrs} visible from {natural_credential}, not {natural_hide_attrs}",
    "Get {natural_show_attrs} from my {natural_credential} while hiding {natural_hide_attrs}",
    "Display {natural_show_attrs} from {natural_credential} and conceal {natural_hide_attrs}"
]

# Natural query templates for Pattern 4 with diverse constraints
PATTERN4_NATURAL_TEMPLATES = {
    "license_class": [
        "Show my driver's license if it's for {value}",
        "I need my license but only if it allows me to drive {value}",
        "Display driver's license for {value} only",
        "Show license if it's {value} class",
        "Get my driving permit if it covers {value}"
    ],
    "vaccination_type": [
        "Show my vaccination certificate if it's for {value}",
        "Display my {value} vaccination record",
        "I need proof of {value} vaccination",
        "Show vaccination if it was {value}",
        "Get my immunization record for {value}"
    ],
    "credit_score": [
        "Show my credit report if the score is {comparison} {value}",
        "Display credit score only if it's {comparison} {value}",
        "I need my credit rating if it's {comparison} {value}",
        "Show financial score when {comparison} {value}",
        "Get credit report with score {comparison} {value}"
    ],
    "gpa": [
        "Show my transcript if GPA is {comparison} {value}",
        "I need academic records with GPA {comparison} {value}",
        "Display grades only if GPA {comparison} {value}",
        "Show transcript when grade average is {comparison} {value}",
        "Get my academic record if performance is {comparison} {value}"
    ],
    "employment_type": [
        "Show my employee ID if I'm {value}",
        "Display work ID for {value} position only",
        "I need employee card if employment is {value}",
        "Show work credentials for {value} staff",
        "Get employee ID when status is {value}"
    ],
    "insurance_type": [
        "Show my health insurance if it's {value}",
        "Display insurance card for {value} coverage",
        "I need insurance proof if it's {value} type",
        "Show coverage details for {value} insurance",
        "Get my {value} insurance information"
    ],
    "blood_type": [
        "Show my blood type certificate if I'm type {value}",
        "Display blood group record for type {value}",
        "I need blood type proof if it's {value}",
        "Show medical record with blood type {value}",
        "Get blood classification if it's group {value}"
    ],
    "degree_type": [
        "Show my university degree if it's a {value}",
        "Display education credential for {value} degree",
        "I need my {value} diploma",
        "Show academic qualification if it's {value} level",
        "Get my degree if it's {value} education"
    ],
    "generic": [
        "Show my {credential_type} where {natural_attr} is {value}",
        "I need the {credential_type} with {natural_attr} being {value}",
        "Display {credential_type} if {natural_attr} equals {value}",
        "Show {credential_type} when {natural_attr} is {value}",
        "Get my {credential_type} with {natural_attr} as {value}"
    ]
}

# Natural credential type names
CREDENTIAL_NATURAL_NAMES = {
    "NationalIDCredential": ["national ID", "ID card", "citizen ID", "identification card"],
    "HealthInsuranceCardCredential": ["health insurance", "insurance card", "medical insurance"],
    "MobileDriverLicenseCredential": ["driver's license", "driving license", "driver license", "driving permit"],
    "PassportCredential": ["passport", "travel document", "international ID"],
    "BloodTypeCredential": ["blood type certificate", "blood group record", "blood type card"],
    "VaccinationCertificate": ["vaccination record", "immunization certificate", "vaccine card"],
    "HealthCheckCertificate": ["health check result", "medical examination", "health certificate"],
    "UniversityDegreeCredential": ["university degree", "diploma", "academic degree", "graduation certificate"],
    "AcademicTranscriptCredential": ["transcript", "academic record", "grades", "academic transcript"],
    "EmployeeIDCredential": ["employee ID", "work ID", "staff card", "employee card"],
    "EikenCertificate": ["Eiken certificate", "English test certificate", "English proficiency certificate"],
    "EikenGrade1Certificate": ["Eiken Grade 1", "English Grade 1 certificate", "Eiken level 1"],
    "EikenGrade2Certificate": ["Eiken Grade 2", "English Grade 2 certificate", "Eiken level 2"],
    "TOEICScoreCertificate": ["TOEIC score", "TOEIC certificate", "English test score"],
    "AnnualIncomeCertificate": ["income certificate", "salary certificate", "income proof"],
    "CreditScoreCredential": ["credit score", "credit report", "financial score", "credit rating"],
    "BankAccountCredential": ["bank account", "bank details", "banking information"],
    "TaxPaymentCertificate": ["tax payment proof", "tax certificate", "tax receipt"],
    "ProfessionalLicenseCredential": ["professional license", "work license", "professional certification"]
}

def get_natural_attribute_name(attr: str) -> str:
    """Get a natural language version of an attribute name."""
    for canonical, variations in NATURAL_LANGUAGE_MAPPINGS.items():
        if attr == canonical:
            return random.choice(variations)
    # If not found, create a natural version
    return attr.replace("_", " ").lower()

def get_natural_credential_name(cred_type: str) -> str:
    """Get a natural language version of a credential type."""
    if cred_type in CREDENTIAL_NATURAL_NAMES:
        return random.choice(CREDENTIAL_NATURAL_NAMES[cred_type])
    # Fallback: remove "Credential" or "Certificate" and make it natural
    natural = cred_type.replace("Credential", "").replace("Certificate", "")
    # Add spaces before capital letters
    import re
    natural = re.sub(r'(?<!^)(?=[A-Z])', ' ', natural).lower()
    return natural

def detect_expiration_field(vc: Dict[str, Any]) -> Optional[str]:
    """Detect if VC has any expiration-related field."""
    subject = vc.get("credentialSubject", {})
    for field in EXPIRATION_FIELDS:
        if field in subject:
            return field
    return None

def load_vc_pool(file_path: str) -> List[Dict[str, Any]]:
    """Load the VC pool from JSON file."""
    with open(file_path, 'r', encoding='utf-8') as f:
        return json.load(f)

def compact_vc(vc: Dict[str, Any]) -> str:
    """Convert VC to compact one-line format."""
    compact = json.dumps(vc, separators=(',', ':'), ensure_ascii=False)
    return compact

def get_credential_type(vc: Dict[str, Any]) -> str:
    """Extract the main credential type from a VC."""
    types = vc.get("type", [])
    for t in types:
        if t != "VerifiableCredential":
            return t
    return "UnknownCredential"

def get_vc_attributes(vc: Dict[str, Any]) -> List[str]:
    """Get all attributes from a VC's credentialSubject."""
    subject = vc.get("credentialSubject", {})
    return list(subject.keys())

def create_dcql_with_constraints(
    vc: Dict[str, Any], 
    show_attributes: List[str] = None,
    hide_attributes: List[str] = None,
    value_constraints: Dict[str, Any] = None
) -> Dict[str, Any]:
    """Create DCQL query with show/hide constraints and value filters."""
    cred_type = get_credential_type(vc)
    type_values = [vc.get("type", [])]
    
    # Get actual attributes from the VC
    actual_attributes = get_vc_attributes(vc)
    
    # Determine which attributes to include
    if show_attributes:
        # Only show specified attributes (that actually exist)
        include_attributes = [attr for attr in show_attributes if attr in actual_attributes]
    elif hide_attributes:
        # Show all except hidden attributes
        include_attributes = [attr for attr in actual_attributes if attr not in hide_attributes]
    else:
        # Show all attributes
        include_attributes = actual_attributes
    
    # Always check for expiration field and include if present
    expiration_field = detect_expiration_field(vc)
    if expiration_field and expiration_field not in include_attributes:
        include_attributes.append(expiration_field)
    
    # Create claim paths
    claims = []
    for attr in include_attributes:
        claim = {"path": ["credentialSubject", attr]}
        
        # Add value constraint if specified
        if value_constraints and attr in value_constraints:
            claim["filter"] = {
                "type": "value",
                "value": value_constraints[attr]
            }
        
        claims.append(claim)
    
    # Create the DCQL query
    dcql = {
        "credentials": [
            {
                "id": f"{cred_type.lower().replace('credential', '').replace('certificate', '')}_credential",
                "format": "ldp_vc",
                "meta": {
                    "type_values": type_values
                },
                "claims": claims
            }
        ]
    }
    
    return dcql

def select_vcs_for_example(vc_pool: List[Dict[str, Any]], target_vc: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Select VCs for an example based on 70/30 distribution."""
    if random.random() < 0.7:
        # 70% - single VC
        return [target_vc]
    else:
        # 30% - 2-3 VCs
        num_vcs = random.randint(2, 3)
        other_vcs = [v for v in vc_pool if v != target_vc]
        selected_other = random.sample(other_vcs, min(num_vcs - 1, len(other_vcs)))
        
        # Insert target VC at random position
        target_idx = random.randint(0, len(selected_other))
        selected_vcs = selected_other[:target_idx] + [target_vc] + selected_other[target_idx:]
        return selected_vcs

def generate_pattern1_variations(vc: Dict[str, Any], vc_pool: List[Dict[str, Any]], num_variations: int = 5) -> List[Dict[str, Any]]:
    """Generate multiple variations of Pattern 1 for a single VC."""
    examples = []
    cred_type = get_credential_type(vc)
    available_attrs = get_vc_attributes(vc)
    
    if len(available_attrs) < 1:
        return examples
    
    for _ in range(num_variations):
        # Select VCs based on 70/30 distribution
        selected_vcs = select_vcs_for_example(vc_pool, vc)
        target_idx = selected_vcs.index(vc)
        
        # Select attributes to show (1-3)
        num_attrs = min(len(available_attrs), random.randint(1, 3))
        show_attrs = random.sample(available_attrs, num_attrs)
        
        # Convert to natural language
        natural_attrs = [get_natural_attribute_name(attr) for attr in show_attrs]
        natural_credential = get_natural_credential_name(cred_type)
        
        # Format attributes for query
        if len(natural_attrs) == 1:
            attr_str = natural_attrs[0]
        elif len(natural_attrs) == 2:
            attr_str = f"{natural_attrs[0]} and {natural_attrs[1]}"
        else:
            attr_str = f"{', '.join(natural_attrs[:-1])}, and {natural_attrs[-1]}"
        
        # Create natural language query
        template = random.choice(PATTERN1_NATURAL_TEMPLATES)
        query = template.format(
            natural_attrs=attr_str,
            natural_credential=natural_credential
        )
        
        # Create DCQL
        dcql = create_dcql_with_constraints(vc, show_attributes=show_attrs)
        
        # Format VCs
        vc_strings = []
        for i, v in enumerate(selected_vcs):
            vc_strings.append(f"VC {i + 1}: {compact_vc(v)}")
        
        prompt = f"""Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
{chr(10).join(vc_strings)}

Natural Language Query: {query}

Generate a DCQL query that selects the appropriate credentials and fields:"""
        
        example = {
            "prompt": prompt,
            "completion": json.dumps(dcql, indent=2),
            "metadata": {
                "pattern": "pattern1_show_attributes",
                "query": query,
                "target_vc_index": target_idx
            }
        }
        
        examples.append(example)
    
    return examples

def generate_pattern2_variations(vc: Dict[str, Any], vc_pool: List[Dict[str, Any]], num_variations: int = 5) -> List[Dict[str, Any]]:
    """Generate multiple variations of Pattern 2 for a single VC."""
    examples = []
    cred_type = get_credential_type(vc)
    available_attrs = get_vc_attributes(vc)
    
    if len(available_attrs) < 2:
        return examples
    
    for _ in range(num_variations):
        # Select VCs based on 70/30 distribution
        selected_vcs = select_vcs_for_example(vc_pool, vc)
        target_idx = selected_vcs.index(vc)
        
        # Select attributes to hide (1-2)
        num_hide = min(len(available_attrs) - 1, random.randint(1, 2))
        hide_attrs = random.sample(available_attrs, num_hide)
        
        # Convert to natural language
        natural_hide_attrs = [get_natural_attribute_name(attr) for attr in hide_attrs]
        natural_credential = get_natural_credential_name(cred_type)
        
        # Format attributes for query
        if len(natural_hide_attrs) == 1:
            attr_str = natural_hide_attrs[0]
        else:
            attr_str = f"{natural_hide_attrs[0]} and {natural_hide_attrs[1]}"
        
        # Create natural language query
        template = random.choice(PATTERN2_NATURAL_TEMPLATES)
        query = template.format(
            natural_hide_attrs=attr_str,
            natural_credential=natural_credential
        )
        
        # Create DCQL
        dcql = create_dcql_with_constraints(vc, hide_attributes=hide_attrs)
        
        # Format VCs
        vc_strings = []
        for i, v in enumerate(selected_vcs):
            vc_strings.append(f"VC {i + 1}: {compact_vc(v)}")
        
        prompt = f"""Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
{chr(10).join(vc_strings)}

Natural Language Query: {query}

Generate a DCQL query that selects the appropriate credentials and fields:"""
        
        example = {
            "prompt": prompt,
            "completion": json.dumps(dcql, indent=2),
            "metadata": {
                "pattern": "pattern2_hide_attributes",
                "query": query,
                "target_vc_index": target_idx
            }
        }
        
        examples.append(example)
    
    return examples

def generate_pattern3_variations(vc: Dict[str, Any], vc_pool: List[Dict[str, Any]], num_variations: int = 5) -> List[Dict[str, Any]]:
    """Generate multiple variations of Pattern 3 for a single VC."""
    examples = []
    cred_type = get_credential_type(vc)
    available_attrs = get_vc_attributes(vc)
    
    if len(available_attrs) < 3:
        return examples
    
    for _ in range(num_variations):
        # Select VCs based on 70/30 distribution
        selected_vcs = select_vcs_for_example(vc_pool, vc)
        target_idx = selected_vcs.index(vc)
        
        # Select attributes to show and hide
        num_show = random.randint(1, min(2, len(available_attrs) - 1))
        show_attrs = random.sample(available_attrs, num_show)
        
        remaining_attrs = [a for a in available_attrs if a not in show_attrs]
        num_hide = random.randint(1, min(2, len(remaining_attrs)))
        hide_attrs = random.sample(remaining_attrs, num_hide)
        
        # Convert to natural language
        natural_show_attrs = [get_natural_attribute_name(attr) for attr in show_attrs]
        natural_hide_attrs = [get_natural_attribute_name(attr) for attr in hide_attrs]
        natural_credential = get_natural_credential_name(cred_type)
        
        # Format attributes for query
        show_str = natural_show_attrs[0] if len(natural_show_attrs) == 1 else f"{natural_show_attrs[0]} and {natural_show_attrs[1]}"
        hide_str = natural_hide_attrs[0] if len(natural_hide_attrs) == 1 else f"{natural_hide_attrs[0]} and {natural_hide_attrs[1]}"
        
        # Create natural language query
        template = random.choice(PATTERN3_NATURAL_TEMPLATES)
        query = template.format(
            natural_show_attrs=show_str,
            natural_hide_attrs=hide_str,
            natural_credential=natural_credential
        )
        
        # Create DCQL (showing only the specified attributes)
        dcql = create_dcql_with_constraints(vc, show_attributes=show_attrs)
        
        # Format VCs
        vc_strings = []
        for i, v in enumerate(selected_vcs):
            vc_strings.append(f"VC {i + 1}: {compact_vc(v)}")
        
        prompt = f"""Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
{chr(10).join(vc_strings)}

Natural Language Query: {query}

Generate a DCQL query that selects the appropriate credentials and fields:"""
        
        example = {
            "prompt": prompt,
            "completion": json.dumps(dcql, indent=2),
            "metadata": {
                "pattern": "pattern3_show_and_hide",
                "query": query,
                "target_vc_index": target_idx
            }
        }
        
        examples.append(example)
    
    return examples

def generate_diverse_value_constraints(vc_pool: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Generate diverse value constraint examples beyond just Eiken."""
    examples = []
    
    # Driver's License Class constraints
    for vc in vc_pool:
        if get_credential_type(vc) == "MobileDriverLicenseCredential" and "licenseClass" in vc.get("credentialSubject", {}):
            license_classes = vc["credentialSubject"]["licenseClass"]
            # Handle both list and string
            if isinstance(license_classes, str):
                license_classes = [license_classes]
            
            natural_values = {
                "Regular Vehicle": ["regular cars", "standard vehicles", "normal cars"],
                "Regular Motorcycle": ["motorcycles", "motorbikes", "motorcycle license"],
                "Large Vehicle": ["trucks", "large vehicles", "commercial vehicles"],
                "Class A": ["motorcycles", "motorbikes", "motorcycle license"],
                "Class B": ["regular cars", "standard vehicles", "normal cars"]
            }
            
            for license_class in license_classes:
                if license_class in natural_values:
                    for natural_value in natural_values[license_class]:
                        examples.append({
                            "vc": vc,
                            "constraint_type": "license_class",
                            "attribute": "licenseClass",
                            "value": license_class,
                            "natural_value": natural_value
                        })
    
    # Credit Score constraints
    for vc in vc_pool:
        if get_credential_type(vc) == "CreditScoreCredential" and "creditScore" in vc.get("credentialSubject", {}):
            score = vc["credentialSubject"]["creditScore"]
            comparisons = [
                ("above", "750", lambda x: x > 750),
                ("at least", "700", lambda x: x >= 700),
                ("over", "800", lambda x: x > 800)
            ]
            
            for comp_word, comp_value, comp_func in comparisons:
                if comp_func(score):
                    examples.append({
                        "vc": vc,
                        "constraint_type": "credit_score",
                        "attribute": "creditScore",
                        "value": score,
                        "comparison": comp_word,
                        "comparison_value": comp_value
                    })
    
    # Blood Type constraints
    for vc in vc_pool:
        if get_credential_type(vc) == "BloodTypeCredential" and "bloodType" in vc.get("credentialSubject", {}):
            blood_type = vc["credentialSubject"]["bloodType"]
            examples.append({
                "vc": vc,
                "constraint_type": "blood_type",
                "attribute": "bloodType",
                "value": blood_type
            })
    
    # Degree Type constraints
    for vc in vc_pool:
        if get_credential_type(vc) == "UniversityDegreeCredential" and "degreeType" in vc.get("credentialSubject", {}):
            degree = vc["credentialSubject"]["degreeType"]
            degree_natural = {
                "Bachelor": ["Bachelor's", "undergraduate degree", "Bachelor degree"],
                "Master": ["Master's", "graduate degree", "Master degree"],
                "PhD": ["Doctorate", "PhD", "doctoral degree"]
            }
            
            if degree in degree_natural:
                for natural in degree_natural[degree]:
                    examples.append({
                        "vc": vc,
                        "constraint_type": "degree_type",
                        "attribute": "degreeType",
                        "value": degree,
                        "natural_value": natural
                    })
    
    # Employment Type constraints
    for vc in vc_pool:
        if get_credential_type(vc) == "EmployeeIDCredential" and "employmentType" in vc.get("credentialSubject", {}):
            emp_type = vc["credentialSubject"]["employmentType"]
            emp_natural = {
                "Full-time": ["full-time", "full time employee", "permanent staff"],
                "Part-time": ["part-time", "part time worker", "part-timer"],
                "Contract": ["contractor", "contract worker", "temporary"]
            }
            
            if emp_type in emp_natural:
                for natural in emp_natural[emp_type]:
                    examples.append({
                        "vc": vc,
                        "constraint_type": "employment_type",
                        "attribute": "employmentType",
                        "value": emp_type,
                        "natural_value": natural
                    })
    
    # Insurance Type constraints
    for vc in vc_pool:
        if get_credential_type(vc) == "HealthInsuranceCardCredential" and "insuranceType" in vc.get("credentialSubject", {}):
            ins_type = vc["credentialSubject"]["insuranceType"]
            ins_natural = {
                "National Health Insurance": ["national insurance", "government insurance", "public insurance"],
                "Employee Health Insurance": ["company insurance", "employer insurance", "work insurance"]
            }
            
            if ins_type in ins_natural:
                for natural in ins_natural[ins_type]:
                    examples.append({
                        "vc": vc,
                        "constraint_type": "insurance_type",
                        "attribute": "insuranceType",
                        "value": ins_type,
                        "natural_value": natural
                    })
    
    return examples

def generate_pattern4_variations(vc_pool: List[Dict[str, Any]], num_variations: int = 50) -> List[Dict[str, Any]]:
    """Generate Pattern 4 examples with diverse value constraints."""
    examples = []
    
    # Get diverse constraint examples
    diverse_constraints = generate_diverse_value_constraints(vc_pool)
    
    # Also keep some Eiken examples
    eiken_vcs = []
    grades = ["Grade 1", "Grade Pre-1", "Grade 2", "Grade Pre-2", "Grade 3"]
    
    for i, grade in enumerate(grades):
        vc = {
            "id": f"vc-eiken-{i+1}",
            "@context": ["https://www.w3.org/ns/credentials/v2"],
            "type": ["VerifiableCredential", "EikenCertificate"],
            "issuer": {"id": "https://eiken.or.jp", "name": "Japan English Proficiency Test Association"},
            "credentialSubject": {
                "candidateName": "Taro Yamada",
                "grade": grade,
                "testDate": f"202{3-i}-{str(i+3).zfill(2)}-{str(i+10).zfill(2)}",
                "certificateNumber": f"202{3-i}-{grade.replace(' ', '-')}-{str(i+100).zfill(5)}",
                "validUntil": f"202{5-i}-{str(i+3).zfill(2)}-{str(i+10).zfill(2)}"  # Add expiration
            }
        }
        if grade in ["Grade 1", "Grade Pre-1"]:
            vc["credentialSubject"]["score"] = {"reading": 750 - i*50, "listening": 750 - i*50}
        eiken_vcs.append(vc)
    
    # Mix Eiken and diverse examples
    num_eiken = num_variations // 3  # About 1/3 Eiken
    num_diverse = num_variations - num_eiken
    
    # Generate Eiken examples
    for _ in range(num_eiken):
        target_eiken = random.choice(eiken_vcs)
        target_grade = target_eiken["credentialSubject"]["grade"]
        
        # Select VCs based on 70/30 distribution
        selected_vcs = select_vcs_for_example(vc_pool + eiken_vcs, target_eiken)
        target_idx = selected_vcs.index(target_eiken)
        
        # Create natural query
        grade_natural = {
            "Grade 1": ["1", "level 1", "first grade"],
            "Grade Pre-1": ["Pre-1", "pre-first", "pre-1 level"],
            "Grade 2": ["2", "level 2", "second grade"],
            "Grade Pre-2": ["Pre-2", "pre-second", "pre-2 level"],
            "Grade 3": ["3", "level 3", "third grade"]
        }
        
        natural_grade = random.choice(grade_natural.get(target_grade, [target_grade]))
        template = random.choice(PATTERN4_NATURAL_TEMPLATES["generic"])
        query = template.format(
            credential_type="English test certificate",
            natural_attr="level",
            value=natural_grade
        )
        
        # Create DCQL
        dcql = create_dcql_with_constraints(
            target_eiken,
            value_constraints={"grade": target_grade}
        )
        
        # Format example
        vc_strings = []
        for i, v in enumerate(selected_vcs):
            vc_strings.append(f"VC {i + 1}: {compact_vc(v)}")
        
        prompt = f"""Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
{chr(10).join(vc_strings)}

Natural Language Query: {query}

Generate a DCQL query that selects the appropriate credentials and fields:"""
        
        example = {
            "prompt": prompt,
            "completion": json.dumps(dcql, indent=2),
            "metadata": {
                "pattern": "pattern4_value_constraints",
                "query": query,
                "target_vc_index": target_idx,
                "constraint": {"attribute": "grade", "value": target_grade}
            }
        }
        
        examples.append(example)
    
    # Generate diverse constraint examples
    for i in range(min(num_diverse, len(diverse_constraints))):
        constraint = random.choice(diverse_constraints)
        vc = constraint["vc"]
        
        # Select VCs based on 70/30 distribution
        selected_vcs = select_vcs_for_example(vc_pool, vc)
        target_idx = selected_vcs.index(vc)
        
        # Create query based on constraint type
        if constraint["constraint_type"] == "license_class":
            template = random.choice(PATTERN4_NATURAL_TEMPLATES["license_class"])
            query = template.format(value=constraint["natural_value"])
        elif constraint["constraint_type"] == "credit_score":
            template = random.choice(PATTERN4_NATURAL_TEMPLATES["credit_score"])
            query = template.format(
                comparison=constraint["comparison"],
                value=constraint["comparison_value"]
            )
        elif constraint["constraint_type"] == "blood_type":
            template = random.choice(PATTERN4_NATURAL_TEMPLATES["blood_type"])
            query = template.format(value=constraint["value"])
        elif constraint["constraint_type"] == "degree_type":
            template = random.choice(PATTERN4_NATURAL_TEMPLATES["degree_type"])
            query = template.format(value=constraint["natural_value"])
        elif constraint["constraint_type"] == "employment_type":
            template = random.choice(PATTERN4_NATURAL_TEMPLATES["employment_type"])
            query = template.format(value=constraint["natural_value"])
        elif constraint["constraint_type"] == "insurance_type":
            template = random.choice(PATTERN4_NATURAL_TEMPLATES["insurance_type"])
            query = template.format(value=constraint["natural_value"])
        else:
            continue
        
        # Create DCQL
        dcql = create_dcql_with_constraints(
            vc,
            value_constraints={constraint["attribute"]: constraint["value"]}
        )
        
        # Format example
        vc_strings = []
        for i, v in enumerate(selected_vcs):
            vc_strings.append(f"VC {i + 1}: {compact_vc(v)}")
        
        prompt = f"""Given the following Verifiable Credentials and a natural language query, generate a DCQL query to retrieve the requested information.

Available Verifiable Credentials:
{chr(10).join(vc_strings)}

Natural Language Query: {query}

Generate a DCQL query that selects the appropriate credentials and fields:"""
        
        example = {
            "prompt": prompt,
            "completion": json.dumps(dcql, indent=2),
            "metadata": {
                "pattern": "pattern4_value_constraints",
                "query": query,
                "target_vc_index": target_idx,
                "constraint": constraint
            }
        }
        
        examples.append(example)
    
    return examples[:num_variations]

def generate_dataset_v2_improved(vc_pool: List[Dict[str, Any]], total_train: int = 900, total_test: int = 100):
    """Generate the complete dataset with improved distribution."""
    
    # Calculate distribution
    train_p1 = int(total_train * 0.225)  # 22.5%
    train_p2 = int(total_train * 0.225)  # 22.5%
    train_p3 = int(total_train * 0.225)  # 22.5%
    train_p4 = total_train - train_p1 - train_p2 - train_p3  # Remainder (~32.5%)
    
    test_per_pattern = total_test // 4
    
    all_examples = {
        "train": {
            "pattern1": [],
            "pattern2": [],
            "pattern3": [],
            "pattern4": []
        },
        "test": {
            "pattern1": [],
            "pattern2": [],
            "pattern3": [],
            "pattern4": []
        }
    }
    
    # Filter VCs by attribute count for better pattern generation
    vcs_with_many_attrs = [vc for vc in vc_pool if len(get_vc_attributes(vc)) >= 4]
    vcs_with_some_attrs = [vc for vc in vc_pool if len(get_vc_attributes(vc)) >= 2]
    
    print(f"VCs with 4+ attributes: {len(vcs_with_many_attrs)}")
    print(f"VCs with 2+ attributes: {len(vcs_with_some_attrs)}")
    
    # Generate Pattern 1 examples
    print(f"\nGenerating {train_p1} training examples for Pattern 1...")
    for vc in vcs_with_some_attrs:
        if len(all_examples["train"]["pattern1"]) >= train_p1:
            break
        variations = generate_pattern1_variations(vc, vc_pool, num_variations=10)
        all_examples["train"]["pattern1"].extend(variations[:train_p1 - len(all_examples["train"]["pattern1"])])
    
    # Generate Pattern 2 examples
    print(f"Generating {train_p2} training examples for Pattern 2...")
    for vc in vcs_with_some_attrs:
        if len(all_examples["train"]["pattern2"]) >= train_p2:
            break
        variations = generate_pattern2_variations(vc, vc_pool, num_variations=10)
        all_examples["train"]["pattern2"].extend(variations[:train_p2 - len(all_examples["train"]["pattern2"])])
    
    # Generate Pattern 3 examples
    print(f"Generating {train_p3} training examples for Pattern 3...")
    for vc in vcs_with_many_attrs:
        if len(all_examples["train"]["pattern3"]) >= train_p3:
            break
        variations = generate_pattern3_variations(vc, vc_pool, num_variations=10)
        all_examples["train"]["pattern3"].extend(variations[:train_p3 - len(all_examples["train"]["pattern3"])])
    
    # Generate Pattern 4 examples
    print(f"Generating {train_p4} training examples for Pattern 4...")
    pattern4_examples = generate_pattern4_variations(vc_pool, num_variations=train_p4)
    all_examples["train"]["pattern4"] = pattern4_examples[:train_p4]
    
    # Generate test examples (smaller variations)
    print("\nGenerating test examples...")
    
    # Pattern 1 test
    for vc in random.sample(vcs_with_some_attrs, min(test_per_pattern, len(vcs_with_some_attrs))):
        variations = generate_pattern1_variations(vc, vc_pool, num_variations=1)
        all_examples["test"]["pattern1"].extend(variations)
        if len(all_examples["test"]["pattern1"]) >= test_per_pattern:
            all_examples["test"]["pattern1"] = all_examples["test"]["pattern1"][:test_per_pattern]
            break
    
    # Pattern 2 test
    for vc in random.sample(vcs_with_some_attrs, min(test_per_pattern, len(vcs_with_some_attrs))):
        variations = generate_pattern2_variations(vc, vc_pool, num_variations=1)
        all_examples["test"]["pattern2"].extend(variations)
        if len(all_examples["test"]["pattern2"]) >= test_per_pattern:
            all_examples["test"]["pattern2"] = all_examples["test"]["pattern2"][:test_per_pattern]
            break
    
    # Pattern 3 test
    for vc in random.sample(vcs_with_many_attrs, min(test_per_pattern, len(vcs_with_many_attrs))):
        variations = generate_pattern3_variations(vc, vc_pool, num_variations=1)
        all_examples["test"]["pattern3"].extend(variations)
        if len(all_examples["test"]["pattern3"]) >= test_per_pattern:
            all_examples["test"]["pattern3"] = all_examples["test"]["pattern3"][:test_per_pattern]
            break
    
    # Pattern 4 test
    pattern4_test = generate_pattern4_variations(vc_pool, num_variations=test_per_pattern)
    all_examples["test"]["pattern4"] = pattern4_test[:test_per_pattern]
    
    return all_examples

def save_dataset(examples: Dict[str, Dict[str, List]], base_path: str):
    """Save the dataset to files organized by pattern."""
    for split in ["train", "test"]:
        for pattern in ["pattern1", "pattern2", "pattern3", "pattern4"]:
            pattern_examples = examples[split][pattern]
            
            # Map pattern names to folder names
            folder_map = {
                "pattern1": "pattern1_show_attributes",
                "pattern2": "pattern2_hide_attributes",
                "pattern3": "pattern3_show_and_hide",
                "pattern4": "pattern4_value_constraints"
            }
            
            output_dir = os.path.join(base_path, split, folder_map[pattern])
            output_file = os.path.join(output_dir, "examples.jsonl")
            
            with open(output_file, 'w', encoding='utf-8') as f:
                for example in pattern_examples:
                    f.write(json.dumps(example, ensure_ascii=False) + '\n')
            
            print(f"Saved {len(pattern_examples)} {split} examples to {output_file}")

def main():
    # Set random seed for reproducibility
    random.seed(42)
    
    # Load VC pool
    vc_pool = load_vc_pool("/home/kenon/Work/Research/vc-llm/dataset/v2/llm1/vcs/vc_pool.json")
    
    # Generate dataset
    print("Generating improved DCQL dataset v2 with natural language and diverse constraints...")
    examples = generate_dataset_v2_improved(vc_pool, total_train=900, total_test=100)
    
    # Save dataset
    base_path = "/home/kenon/Work/Research/vc-llm/dataset/v2/llm2"
    save_dataset(examples, base_path)
    
    # Print statistics
    print("\nDataset Statistics:")
    for split in ["train", "test"]:
        print(f"\n{split.upper()}:")
        total = 0
        for pattern in ["pattern1", "pattern2", "pattern3", "pattern4"]:
            count = len(examples[split][pattern])
            total += count
            print(f"  {pattern}: {count} examples")
        print(f"  Total: {total} examples")

if __name__ == "__main__":
    main()